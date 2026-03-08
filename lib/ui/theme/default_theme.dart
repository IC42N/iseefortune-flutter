import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iseefortune_flutter/ui/theme/app_colors.dart';
import 'package:iseefortune_flutter/ui/theme/app_gradients.dart';

class DefaultTheme {
  String get name => 'Default';

  static ThemeData get data {
    // Core surfaces (match your web vibe)
    const bg = Color(0xFF0B0F1A); // app background (deep navy)
    const surface = Color(0xFF0F1629); // cards / sheets
    const surface2 = Color(0xFF111B33); // elevated surfaces
    const border = Color(0x22FFFFFF); // subtle white border

    // Accents (you can tune these to match exact web colors)
    const primary = Color(0xFFEAEAEA); // light text/primary (not neon)
    const accent = Color(0xFF7C5CFF); // purple accent
    const accent2 = Color(0xFF2DE2E6); // cyan accent

    const scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: bg,

      secondary: accent,
      onSecondary: Colors.white,

      tertiary: accent2,
      onTertiary: Colors.black,

      error: Color(0xFFB85C5C),
      onError: Color(0xFFFFE1E1),

      surface: surface,
      onSurface: Color(0xFFE7EAF0),

      // Material3 uses these a lot
      surfaceContainerHighest: surface2,
      onSurfaceVariant: Color(0xFFB7C0D1),

      outline: Color(0x33FFFFFF),
      shadow: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,

      scaffoldBackgroundColor: Colors.transparent,

      appBarTheme: AppBarTheme(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),

      cardColor: surface,
      dividerColor: scheme.outline,

      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: false,
        dragHandleColor: scheme.onSurface.withOpacityCompat(0.7),
        backgroundColor: surface,
        modalBackgroundColor: surface2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(0))),
        elevation: 10,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: scheme.onSurface, // light button on dark bg
          foregroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.onSurface.withOpacityCompat(0.35)),
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      textTheme: TextTheme(
        // Main Dashboard balance
        displayLarge: GoogleFonts.saira(fontSize: 60, color: scheme.onSurface, fontWeight: FontWeight.w600),
        displayMedium: GoogleFonts.saira(fontSize: 50, color: scheme.onSurface, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.saira(fontSize: 16, color: scheme.onSurface),
        titleSmall: GoogleFonts.saira(fontSize: 12, color: scheme.onSurface.withOpacityCompat(0.85)),
        bodyMedium: GoogleFonts.saira(fontSize: 13, color: scheme.onSurface),
        bodySmall: GoogleFonts.saira(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface.withOpacityCompat(0.78),
          letterSpacing: 0.2,
        ),
        labelMedium: GoogleFonts.saira(fontSize: 20, color: scheme.onSurface.withOpacityCompat(0.78)),
        labelSmall: GoogleFonts.saira(fontSize: 14, color: scheme.onSurface.withOpacityCompat(0.78)),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.onSurface,
        selectionColor: accent.withOpacityCompat(0.35),
        selectionHandleColor: scheme.onSurface,
      ),

      sliderTheme: SliderThemeData(
        valueIndicatorColor: scheme.onSurface,
        valueIndicatorTextStyle: TextStyle(color: bg),
        activeTrackColor: scheme.onSurface,
        inactiveTrackColor: scheme.onSurface.withOpacityCompat(0.25),
        thumbColor: scheme.onSurface,
        overlayColor: scheme.onSurface.withOpacityCompat(0.08),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: surface2,
        contentTextStyle: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),

      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: scheme.onSurface.withOpacityCompat(0.75)),
        floatingLabelStyle: TextStyle(color: scheme.onSurface.withOpacityCompat(0.92)),

        filled: true,
        fillColor: surface2,

        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: border),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent.withOpacityCompat(0.9), width: 1.6),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 1.2),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 1.6),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),

      extensions: const [
        AppGradients(
          // You can use this for fancy dashboard backgrounds
          dashboardBackground: [Color(0xFF0B0F1A), Color(0xFF0C1324), Color(0xFF0F1A33)],
          background: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F1A), Color(0xFF0C1324), Color(0xFF0F1A33)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      ],
    );
  }
}
