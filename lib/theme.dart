import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ThemePreset { defaultGray, system }

class AppTheme {
  // Premium Silver/Gray Palette (Default)
  // Using a sophisticated Slate/Neutral Grey instead of BlueGrey
  // Premium Silver/Gray Palette (Default)
  // Using a sophisticated Slate/Neutral Grey instead of BlueGrey
  static const Color premiumSilver =
      Color(0xFF8E8E93); // iOS System Grey (Light)
  static const Color premiumSilverDark =
      Color(0xFF1C1C1E); // iOS System Grey 6 (Dark)

  // A solid Slate Grey for the "Seed" to ensure buttons/toggles have contrast.
  // Pure light grey seed makes things invisible.
  static const Color premiumSeed = Colors.grey; // Neutral Seed

  // Restored Pastel Colors (Used in other screens)
  static const Color pastelRed = Color(0xFFFF6961);
  static const Color pastelRedDark = Color(0xFFD64545);
  static const Color pastelGreen = Color(0xFF77DD77);
  static const Color pastelBlue = Color(0xFFAEC6CF);
  static const Color pastelYellow = Color(0xFFFFD700);

  // Cyberpunk Palette (Used in presets previously, kept for safety or re-use)
  static const Color cyberNeonPink = Color(0xFFFF007F);
  static const Color cyberNeonCyan = Color(0xFF00FFFF);

  // Custom Fallback
  static const Color defaultCustomColor = Color(0xFF6750A4); // Material Purple

  static TextTheme get _textTheme => GoogleFonts.outfitTextTheme();

  static ThemeData lightTheme(ColorScheme? dynamicColorScheme,
      {ThemePreset preset = ThemePreset.system,
      Color? customThemeColor,
      bool isNeon = false}) {
    ColorScheme baseScheme;

    if (preset == ThemePreset.system) {
      baseScheme = dynamicColorScheme ??
          ColorScheme.fromSeed(
            seedColor: premiumSeed,
            brightness: Brightness.light,
          );
      // If the incoming system theme is Grey/Neutral, strictly remove generated tints
      if (_isGrey(baseScheme.primary)) {
        baseScheme = _makeMonochrome(baseScheme);
      }
    } else {
      // Default Gray - Strict Monochromatic Calibration to prevent Teal drift
      baseScheme = ColorScheme.fromSeed(
        seedColor: premiumSeed, // Slate for contrast
        brightness: Brightness.light,
        primary:
            const Color(0xFF48484A), // Distinct Premium Graphite for Light Mode
        surface: const Color(
            0xFFF2F2F7), // Premium distinctive Light Grey background

        // Force Secondary/Tertiary to be Grey to avoid computed "Teal" tints
        secondary: const Color(0xFF5A5A5A),
        onSecondary: Colors.white,
        tertiary: const Color(0xFF757575),
        onTertiary: Colors.white,
        outline: const Color(0xFF8E8E93),
      );
      // Strictly remove any generated "Teal/Blue" tints from containers
      baseScheme = _makeMonochrome(baseScheme);
    }

    // Refine Logic
    final ColorScheme refinedScheme = baseScheme.copyWith(
      surface: (preset == ThemePreset.defaultGray)
          ? const Color(0xFFF2F2F7) // Explicit Apple-like Grouped Background
          : baseScheme.surface,
      surfaceContainer: (preset == ThemePreset.defaultGray)
          ? Colors.white // Cards/Containers pop against the grey bg
          : baseScheme.surfaceContainer,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: refinedScheme,
      textTheme: _textTheme.apply(
        bodyColor: refinedScheme.onSurface,
        displayColor: refinedScheme.onSurface,
      ),
      scaffoldBackgroundColor: refinedScheme.surface,
      cardColor: (preset == ThemePreset.defaultGray) ? Colors.white : null,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: refinedScheme.onSurface),
        titleTextStyle: _textTheme.titleLarge?.copyWith(
          color: refinedScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData darkTheme(ColorScheme? dynamicColorScheme,
      {ThemePreset preset = ThemePreset.defaultGray,
      Color? customThemeColor,
      bool isNeon = false}) {
    ColorScheme baseScheme;

    if (preset == ThemePreset.system) {
      baseScheme = (dynamicColorScheme?.copyWith(
            surface: Colors.black,
            onSurface: Colors.white,
            surfaceContainer: const Color(0xFF121212),
          )) ??
          ColorScheme.fromSeed(
            seedColor: premiumSilver,
            brightness: Brightness.dark,
            surface: Colors.black,
            onSurface: Colors.white,
            surfaceContainer: const Color(0xFF121212),
          );
      // If the incoming system theme is Grey/Neutral, strictly remove generated tints
      if (_isGrey(baseScheme.primary)) {
        baseScheme = _makeMonochrome(baseScheme);
      }
    } else {
      // Default Gray Dark - Strict Monochromatic Calibration
      baseScheme = ColorScheme.fromSeed(
        seedColor: Colors.grey, // Force neutral seed
        brightness: Brightness.dark,
        primary: const Color(
            0xFFE5E5EA), // Explicit "Premium Grade Light Grey" Accent
        primaryContainer: const Color(0xFF2C2C2E), // Forced Dark Grey Container
        onPrimaryContainer: Colors.white,
        surface: const Color(0xFF000000), // Pure Black for OLED/Premium feel

        // Force Secondary/Tertiary to be Grey to avoid computed "Teal" tints
        secondary: const Color(0xFFD1D1D6),
        onSecondary: Colors.black,
        tertiary: const Color(0xFF8E8E93),
        onTertiary: Colors.black,
        outline: const Color(0xFF636366),

        onSurface: Colors.white,
        surfaceContainer: const Color(0xFF1C1C1E), // Dark Grey containers
      );
      // Strictly remove any generated "Teal/Blue" tints from containers
      baseScheme = _makeMonochrome(baseScheme);
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: baseScheme,
      textTheme: _textTheme.apply(
        bodyColor: baseScheme.onSurface,
        displayColor: baseScheme.onSurface,
      ),
      scaffoldBackgroundColor: baseScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: _textTheme.titleLarge?.copyWith(
          color: baseScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // --- Helpers to prevent "Teal Drift" on Neutrals ---

  static bool _isGrey(Color c) {
    // Check strict saturation.
    // Relaxed threshold to 0.3 to catch BlueGrey/Sand/Slate system themes.
    return HSVColor.fromColor(c).saturation < 0.3;
  }

  static ColorScheme _makeMonochrome(ColorScheme scheme) {
    // Manually desaturate key roles to ensure strict greyscale
    // preserving luminance constraints calculated by Material.
    return scheme.copyWith(
      primary: _desaturate(scheme.primary),
      onPrimary: _desaturate(scheme.onPrimary),
      primaryContainer: _desaturate(scheme.primaryContainer),
      onPrimaryContainer: _desaturate(scheme.onPrimaryContainer),
      secondary: _desaturate(scheme.secondary),
      onSecondary: _desaturate(scheme.onSecondary),
      secondaryContainer: _desaturate(scheme.secondaryContainer),
      onSecondaryContainer: _desaturate(scheme.onSecondaryContainer),
      tertiary: _desaturate(scheme.tertiary),
      onTertiary: _desaturate(scheme.onTertiary),
      tertiaryContainer: _desaturate(scheme.tertiaryContainer),
      onTertiaryContainer: _desaturate(scheme.onTertiaryContainer),
      // Backgrounds/Surfaces often get a subtle tint in M3, remove it for "Premium" feel
      surface: _desaturate(scheme.surface),
      onSurface: _desaturate(scheme.onSurface),
      surfaceContainer: _desaturate(scheme.surfaceContainer),
      surfaceContainerHigh: _desaturate(scheme.surfaceContainerHigh),
      surfaceContainerHighest: _desaturate(scheme.surfaceContainerHighest),
      surfaceContainerLow: _desaturate(scheme.surfaceContainerLow),
      surfaceContainerLowest: _desaturate(scheme.surfaceContainerLowest),
      outline: _desaturate(scheme.outline),
      outlineVariant: _desaturate(scheme.outlineVariant),
    );
  }

  static Color _desaturate(Color c) {
    final hsv = HSVColor.fromColor(c);
    return hsv.withSaturation(0).toColor();
  }
}
