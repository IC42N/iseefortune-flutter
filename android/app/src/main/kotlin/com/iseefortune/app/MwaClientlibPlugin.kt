package com.iseefortune.app

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Base64
import android.util.Log
import androidx.activity.ComponentActivity
import com.funkatronics.encoders.Base58
import com.solana.mobilewalletadapter.clientlib.ActivityResultSender
import com.solana.mobilewalletadapter.clientlib.ConnectionIdentity
import com.solana.mobilewalletadapter.clientlib.MobileWalletAdapter
import com.solana.mobilewalletadapter.clientlib.RpcCluster
import com.solana.mobilewalletadapter.clientlib.Solana
import com.solana.mobilewalletadapter.clientlib.TransactionResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Flutter bridge for Solana Mobile Wallet Adapter (MWA).
 *
 * Responsibilities:
 * - Connect to an installed MWA-compatible wallet
 * - Persist native wallet session details for reuse
 * - Restore auth token + wallet URI base onto the adapter
 * - Sign FULL serialized unsigned Solana transactions
 *
 * Important behavior:
 * - "connect" may open wallet picker / wallet authorization UI
 * - "signTransaction" should reuse the existing authorization when possible
 * - Kotlin signs only; Flutter sends + confirms through RPC
 *
 * Notes:
 * - Local disconnect clears stored session state without intentionally reopening wallet UI
 * - Operations are serialized with a Mutex to avoid overlapping wallet flows
 */
class MwaClientlibPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    companion object {
        private const val TAG = "MWA_CLIENTLIB"

        private const val PREFS_NAME = "mwa_clientlib_prefs"
        private const val KEY_AUTH_TOKEN = "mwa_auth_token"
        private const val KEY_PUBLIC_KEY_B58 = "mwa_public_key_b58"
        private const val KEY_WALLET_URI_BASE = "mwa_wallet_uri_base"
    }

    // -------------------------------------------------------------------------
    // Persisted native session state
    // -------------------------------------------------------------------------

    private var prefs: SharedPreferences? = null
    private var currentAuthToken: String? = null
    private var currentPublicKeyB58: String? = null
    private var currentWalletUriBase: String? = null

    // -------------------------------------------------------------------------
    // Flutter / Android state
    // -------------------------------------------------------------------------

    private lateinit var channel: MethodChannel
    private var activity: ComponentActivity? = null
    private var sender: ActivityResultSender? = null
    private var walletAdapter: MobileWalletAdapter? = null

    /** Prevent overlapping connect/sign/disconnect operations. */
    private val opMutex = Mutex()

    /** Main-scope coroutine runner for async plugin work. */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // -------------------------------------------------------------------------
    // FlutterPlugin lifecycle
    // -------------------------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        prefs = binding.applicationContext.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE
        )

        channel = MethodChannel(binding.binaryMessenger, "mwa_clientlib")
        channel.setMethodCallHandler(this)

        restorePersistedSession()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        prefs = null
    }

    // -------------------------------------------------------------------------
    // ActivityAware lifecycle
    // -------------------------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity as? ComponentActivity
        ensureWalletAdapter()
        ensureSender()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity as? ComponentActivity
        ensureWalletAdapter()
        ensureSender()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        sender = null
        activity = null
    }

    override fun onDetachedFromActivity() {
        sender = null
        activity = null
    }

    // -------------------------------------------------------------------------
    // Session persistence
    // -------------------------------------------------------------------------

    /**
     * Restore previously persisted native wallet session values.
     *
     * If an auth token exists, restore it onto the adapter so reauthorization
     * can happen without forcing a fresh wallet selection.
     *
     * If a wallet URI base exists, restore it onto the adapter so the same
     * wallet app can be targeted directly instead of reopening the picker.
     */
    private fun restorePersistedSession() {
        val p = prefs ?: return

        currentAuthToken = p.getString(KEY_AUTH_TOKEN, null)
        currentPublicKeyB58 = p.getString(KEY_PUBLIC_KEY_B58, null)
        currentWalletUriBase = p.getString(KEY_WALLET_URI_BASE, null)

        Log.i(
            TAG,
            "restorePersistedSession: authTokenPresent=${!currentAuthToken.isNullOrBlank()} " +
                "pubkey=$currentPublicKeyB58 walletUriBase=$currentWalletUriBase"
        )

        ensureWalletAdapter()

        if (!currentAuthToken.isNullOrBlank()) {
            walletAdapter?.authToken = currentAuthToken
            Log.i(TAG, "restorePersistedSession: restored auth token onto walletAdapter")
        }

        restoreWalletUriBaseOntoAdapter()
    }

    /**
     * Persist the current native wallet session details after a successful connect.
     */
    private fun persistSession(
        authToken: String?,
        publicKeyB58: String?,
        walletUriBase: String?
    ) {
        currentAuthToken = authToken
        currentPublicKeyB58 = publicKeyB58
        currentWalletUriBase = walletUriBase

        prefs?.edit()
            ?.putString(KEY_AUTH_TOKEN, authToken)
            ?.putString(KEY_PUBLIC_KEY_B58, publicKeyB58)
            ?.putString(KEY_WALLET_URI_BASE, walletUriBase)
            ?.apply()

        Log.i(
            TAG,
            "persistSession: authTokenPresent=${!authToken.isNullOrBlank()} " +
                "pubkey=$publicKeyB58 walletUriBase=$walletUriBase"
        )
    }

    /**
     * Clear all locally persisted wallet session state.
     */
    private fun clearPersistedSession() {
        currentAuthToken = null
        currentPublicKeyB58 = null
        currentWalletUriBase = null

        prefs?.edit()
            ?.remove(KEY_AUTH_TOKEN)
            ?.remove(KEY_PUBLIC_KEY_B58)
            ?.remove(KEY_WALLET_URI_BASE)
            ?.apply()

        Log.i(TAG, "clearPersistedSession: cleared")
    }

    // -------------------------------------------------------------------------
    // Initialization helpers
    // -------------------------------------------------------------------------

    /**
     * Create the ActivityResultSender once a valid ComponentActivity is attached.
     */
    private fun ensureSender() {
        if (sender != null) return
        val act = activity ?: return
        sender = ActivityResultSender(act)
    }

    /**
     * Create the MobileWalletAdapter once.
     *
     * If a cached auth token exists, restore it onto the new adapter instance.
     * If a cached wallet URI base exists, restore that too so direct wallet
     * targeting can continue across app restarts.
     */
    private fun ensureWalletAdapter() {
        if (walletAdapter != null) return

        val identityUri = Uri.parse("https://iseefortune.com")
        val iconUri = Uri.parse("favicon.ico")
        val identityName = "I See Fortune"

        walletAdapter = MobileWalletAdapter(
            connectionIdentity = ConnectionIdentity(
                identityUri = identityUri,
                iconUri = iconUri,
                identityName = identityName
            )
        ).apply {
            blockchain = Solana.Mainnet
            rpcCluster = RpcCluster.MainnetBeta

            if (!currentAuthToken.isNullOrBlank()) {
                authToken = currentAuthToken
                Log.i(TAG, "ensureWalletAdapter: restored authToken onto new adapter")
            }
        }

        restoreWalletUriBaseOntoAdapter()

        Log.i(
            TAG,
            "ensureWalletAdapter: adapter ready " +
                "authTokenPresent=${!walletAdapter?.authToken.isNullOrBlank()} " +
                "walletUriBase=$currentWalletUriBase"
        )
    }

    /**
     * Reassert mainnet configuration and restore cached auth token / wallet URI
     * base if needed.
     */
    private fun forceMainnet() {
        ensureWalletAdapter()

        walletAdapter!!.blockchain = Solana.Mainnet
        walletAdapter!!.rpcCluster = RpcCluster.MainnetBeta

        if (walletAdapter?.authToken.isNullOrBlank() && !currentAuthToken.isNullOrBlank()) {
            walletAdapter?.authToken = currentAuthToken
            Log.i(TAG, "forceMainnet: restored currentAuthToken onto adapter")
        }

        restoreWalletUriBaseOntoAdapter()
    }

    /**
     * Safely get the ActivityResultSender, otherwise fail the Flutter request.
     */
    private fun requireSender(result: MethodChannel.Result): ActivityResultSender? {
        val s = sender
        if (s != null) return s

        result.error(
            "NO_SENDER",
            "ActivityResultSender not initialized. Plugin may have attached too late.",
            null
        )
        return null
    }

    // -------------------------------------------------------------------------
    // MethodChannel entrypoint
    // -------------------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> handleConnect(result)
            "disconnect" -> handleDisconnect(result)
            "signTransaction" -> handleSignTransaction(call, result)
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // Connect
    // -------------------------------------------------------------------------

    /**
     * Interactive wallet connect / authorize flow.
     *
     * On success:
     * - stores auth token
     * - stores selected pubkey
     * - stores walletUriBase if returned by wallet
     * - applies wallet-specific fallback URI base if needed
     */
    private fun handleConnect(result: MethodChannel.Result) {
        ensureWalletAdapter()
        ensureSender()
        val s = requireSender(result) ?: return

        scope.launch {
            opMutex.withLock {
                try {
                    forceMainnet()

                    val r = walletAdapter!!.connect(s)

                    when (r) {
                        is TransactionResult.Success -> {
                            val pkBytes = r.authResult.accounts.first().publicKey
                            val publicKeyB58 = Base58.encodeToString(pkBytes)
                            val authToken = walletAdapter!!.authToken

                            // Some wallets return walletUriBase directly.
                            // Others do not, so we fall back to a known URI base
                            // using the returned account label when possible.
                            var walletUriBase = r.authResult.walletUriBase?.toString()
                            if (walletUriBase == null) {
                                walletUriBase = fallbackWalletUriBase(r.authResult.accountLabel)
                                if (walletUriBase != null) {
                                    Log.i(
                                        TAG,
                                        "connect fallback walletUriBase=$walletUriBase " +
                                            "(via accountLabel=${r.authResult.accountLabel})"
                                    )
                                }
                            }

                            Log.i(TAG, "connect success")
                            Log.i(TAG, "connect success accountLabel=${r.authResult.accountLabel}")
                            Log.i(TAG, "connect success publicKeyB58=$publicKeyB58")
                            Log.i(TAG, "connect success authTokenPresent=${!authToken.isNullOrBlank()}")
                            Log.i(TAG, "connect success authTokenLength=${authToken?.length ?: 0}")
                            Log.i(TAG, "connect success walletUriBase=$walletUriBase")

                            persistSession(authToken, publicKeyB58, walletUriBase)

                            result.success(
                                mapOf(
                                    "ok" to true,
                                    "publicKeyBytes" to pkBytes,
                                    "publicKeyB58" to publicKeyB58,
                                    "authToken" to authToken,
                                    "walletUriBase" to walletUriBase
                                )
                            )
                        }

                        is TransactionResult.NoWalletFound -> {
                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "code" to "NO_WALLET_FOUND"
                                )
                            )
                        }

                        is TransactionResult.Failure -> {
                            val root = run {
                                var t: Throwable? = r.e
                                while (t?.cause != null && t.cause !== t) t = t.cause
                                t ?: r.e
                            }

                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "code" to "FAILURE",
                                    "message" to (root.message ?: r.e.message ?: "Unknown error"),
                                    "etype" to root.javaClass.name
                                )
                            )
                        }
                    }
                } catch (t: Throwable) {
                    result.success(
                        mapOf(
                            "ok" to false,
                            "code" to "FAILURE",
                            "message" to (t.message ?: "Unknown error"),
                            "etype" to t.javaClass.name
                        )
                    )
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Disconnect
    // -------------------------------------------------------------------------

    /**
     * Local disconnect / session clear.
     *
     * This intentionally clears local state without trying to drive the user
     * through a wallet UI flow.
     */
    private fun handleDisconnect(result: MethodChannel.Result) {
        scope.launch {
            opMutex.withLock {
                Log.i(TAG, "disconnect: clearing local session")
                walletAdapter?.authToken = null
                clearPersistedSession()
                walletAdapter = null
                result.success(mapOf("ok" to true))
            }
        }
    }

    // -------------------------------------------------------------------------
    // Sign transaction
    // -------------------------------------------------------------------------

    /**
     * Sign a FULL serialized unsigned Solana transaction and return the signed
     * transaction bytes back to Flutter.
     *
     * Flutter provides:
     * - transactionB64: base64-encoded serialized unsigned transaction bytes
     *
     * Kotlin returns:
     * - signedTransactionB64
     *
     * Important:
     * - This signs only
     * - Flutter is responsible for send + confirm via RPC
     */
    private fun handleSignTransaction(call: MethodCall, result: MethodChannel.Result) {
        Log.i(TAG, "handleSignTransaction: entered")
        Log.i(TAG, "handleSignTransaction: adapter exists=${walletAdapter != null}")
        Log.i(TAG, "handleSignTransaction: adapter authTokenPresent=${!walletAdapter?.authToken.isNullOrBlank()}")
        Log.i(TAG, "handleSignTransaction: currentAuthTokenPresent=${!currentAuthToken.isNullOrBlank()}")
        Log.i(TAG, "handleSignTransaction: currentPublicKeyB58=$currentPublicKeyB58")
        Log.i(TAG, "handleSignTransaction: currentWalletUriBase=$currentWalletUriBase")

        ensureWalletAdapter()
        ensureSender()
        val s = requireSender(result) ?: return

        val transactionB64 = call.argument<String>("transactionB64")
        if (transactionB64.isNullOrBlank()) {
            result.error("BAD_ARGS", "Missing transactionB64", null)
            return
        }

        val txBytes = Base64.decode(transactionB64, Base64.DEFAULT)
        Log.i(TAG, "handleSignTransaction: transactionB64 length=${transactionB64.length}")
        Log.i(TAG, "handleSignTransaction: txBytes size=${txBytes.size}")

        scope.launch {
            opMutex.withLock {
                try {
                    forceMainnet()

                    if (walletAdapter?.authToken.isNullOrBlank()) {
                        Log.e(TAG, "handleSignTransaction: NOT_CONNECTED because adapter authToken is null/blank")
                        result.success(
                            mapOf(
                                "ok" to false,
                                "code" to "NOT_CONNECTED"
                            )
                        )
                        return@withLock
                    }

                    val r = walletAdapter!!.transact(s) { authResult ->
                        Log.i(TAG, "handleSignTransaction: transact lambda entered")
                        Log.i(TAG, "handleSignTransaction: authResult accounts size=${authResult.accounts.size}")

                        // Request signed transaction bytes back from the wallet.
                        signTransactions(arrayOf(txBytes))
                    }

                    Log.i(TAG, "handleSignTransaction: transact returned type=${r::class.java.name}")

                    when (r) {
                        is TransactionResult.Success -> {
                            Log.i(TAG, "handleSignTransaction: SUCCESS")

                            val signedTxBytes = extractSignedTransactionByteArray(r) ?: ByteArray(0)

                            if (signedTxBytes.isEmpty()) {
                                result.success(
                                    mapOf(
                                        "ok" to false,
                                        "code" to "NO_SIGNED_TX"
                                    )
                                )
                            } else {
                                result.success(
                                    mapOf(
                                        "ok" to true,
                                        "signedTransactionB64" to Base64.encodeToString(
                                            signedTxBytes,
                                            Base64.NO_WRAP
                                        )
                                    )
                                )
                            }
                        }

                        is TransactionResult.NoWalletFound -> {
                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "code" to "NO_WALLET_FOUND"
                                )
                            )
                        }

                        is TransactionResult.Failure -> {
                            val root = run {
                                var t: Throwable? = r.e
                                while (t?.cause != null && t.cause !== t) t = t.cause
                                t ?: r.e
                            }

                            Log.e(TAG, "handleSignTransaction: FAILURE root=${root.javaClass.name} msg=${root.message}")

                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "code" to "FAILURE",
                                    "message" to (root.message ?: r.e.message ?: "Unknown error"),
                                    "etype" to root.javaClass.name
                                )
                            )
                        }
                    }
                } catch (t: Throwable) {
                    result.success(
                        mapOf(
                            "ok" to false,
                            "code" to "FAILURE",
                            "message" to (t.message ?: "Unknown error"),
                            "etype" to t.javaClass.name
                        )
                    )
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Adapter walletUriBase restore
    // -------------------------------------------------------------------------

    /**
     * Restore the cached wallet URI base onto the adapter via reflection.
     *
     * MWA clientlib keeps walletUriBase internally and does not expose a public
     * setter, so reflection is used here to preserve direct wallet targeting
     * across app sessions.
     */
    private fun restoreWalletUriBaseOntoAdapter() {
        val base = currentWalletUriBase ?: return
        val adapter = walletAdapter ?: return

        try {
            val f = adapter.javaClass.getDeclaredField("walletUriBase")
            f.isAccessible = true
            f.set(adapter, Uri.parse(base))
            Log.i(TAG, "restoreWalletUriBaseOntoAdapter: restored walletUriBase=$base")
        } catch (t: Throwable) {
            Log.e(TAG, "restoreWalletUriBaseOntoAdapter: failed", t)
        }
    }

    // -------------------------------------------------------------------------
    // Signed transaction extraction
    // -------------------------------------------------------------------------

    /**
     * Extract the first signed transaction from a successful signTransactions result.
     *
     * Current observed clientlib shape:
     * - TransactionResult.Success
     *   -> getPayload()
     *   -> MobileWalletAdapterClient.SignPayloadsResult
     *   -> signedPayloads: Array<ByteArray>
     *
     * We keep one small fallback for getter-based access in case another clientlib
     * build exposes signed payloads through a getter instead of a field.
     */
    private fun extractSignedTransactionByteArray(success: Any): ByteArray? {
        return try {
            val payload = success.javaClass.methods
                .firstOrNull { it.name == "getPayload" }
                ?.invoke(success)
                ?: return null

            // Preferred current path: SignPayloadsResult.signedPayloads
            runCatching {
                val field = payload.javaClass.getDeclaredField("signedPayloads")
                field.isAccessible = true
                val arr = field.get(payload) as? Array<*>
                arr?.firstOrNull() as? ByteArray
            }.getOrNull()
                ?:
                // Small fallback in case a future clientlib exposes a getter instead.
                runCatching {
                    val method = payload.javaClass.methods.firstOrNull { it.name == "getSignedPayloads" }
                    val arr = method?.invoke(payload) as? Array<*>
                    arr?.firstOrNull() as? ByteArray
                }.getOrNull()
        } catch (t: Throwable) {
            Log.e(TAG, "extractSignedTransactionByteArray: failed", t)
            null
        }
    }

    // -------------------------------------------------------------------------
    // Wallet fallback URI map
    // -------------------------------------------------------------------------

    /**
     * Return a known wallet universal-link base from the wallet account label.
     *
     * This is used only when the wallet does not return walletUriBase itself.
     *
     * Supported fallback mappings:
     * - Phantom  -> https://phantom.app/ul/v1
     * - Backpack -> https://backpack.app/ul/v1
     * - Solflare -> https://solflare.com/ul/v1
     *
     * Unknown wallets return null and will continue through the generic picker flow.
     */
    private fun fallbackWalletUriBase(walletLabel: String?): String? {
        val label = walletLabel?.lowercase() ?: return null

        return when {
            label.contains("phantom") -> "https://phantom.app/ul/v1"
            label.contains("backpack") -> "https://backpack.app/ul/v1"
            label.contains("solflare") -> "https://solflare.com/ul/v1"
            else -> null
        }
    }
}