import 'package:solana/solana.dart';

const String programId = 'ic429goRDdS7BXEDYr2nZeAYMxtT6FL3AsB3sneaSu7';
const String configPda = '86oxs9QvnZPUpYj4fdkmWZ4nUP1okXyiQgjquQpfsicm';
const String liveFeedPda = 'A1oCTKuhbAqgNp142PsnmHZypm6P9bvsxPYtfbAepKCg';

final programPubkey = Ed25519HDPublicKey.fromBase58(programId);
