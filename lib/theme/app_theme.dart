import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Daily Ritual Dashboard - Multi-Theme System
class AppTheme {
  // ════════════════════════════════════════════════════════════════════════════
  // LAVENDER DREAM (Default)
  // ════════════════════════════════════════════════════════════════════════════

  // Light Mode
  static const Color primaryText = Color(0xFF5D5470);
  static const Color lavenderPrimary = Color(0xFF7B6F93);
  static const Color backgroundLight = Color(0xFFFDFCFE);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Dark Mode
  static const Color backgroundDark = Color(0xFF282635);
  static const Color cardDark = Color(0xFF33313F);
  static const Color twilightPale = Color(0xFFE2E0EB); // Text
  static const Color twilightAccent = Color(0xFFA39EB8); // Buttons
  static const Color skyHaze = Color(0xFFD1D9E6);

  // Accents
  static const Color lavenderLight = Color(0xFFE9E6F2);
  static const Color lavenderAccent = Color(0xFFF3F1FF);
  static const Color lavenderSageAccent = Color(0xFF4A6B6B);

  // ════════════════════════════════════════════════════════════════════════════
  // SUNRISE GLOW (New)
  // ════════════════════════════════════════════════════════════════════════════

  // Light Mode
  static const Color sunrisePrimaryText = Color(0xFF8B5E52); // Terracotta
  static const Color sunrisePrimary = Color(0xFFD48C70); // Muted Apricot
  static const Color sunriseBackgroundLight = Color(0xFFFFFBF7); // Cream
  static const Color sunriseCardLight = Color(0xFFFFFFFF);
  static const Color sunriseAccentLight = Color(0xFFFDF2E9);

  // Dark Mode (Rich Desert Dusk)
  static const Color sunriseBackgroundDark = Color(0xFF1A1614); // Dusk Charcoal
  static const Color sunriseCardDark = Color(0xFF261E1A); // Darker Sepia
  static const Color sunriseTextDark = Color(0xFFF2EBE3); // Dusk Off-White
  static const Color sunriseAccentDark = Color(0xFF8E4C3D); // Dusk Terracotta
  static const Color sunriseMutedDark = Color(0xFFA68B7C); // Peach Brown

  // ════════════════════════════════════════════════════════════════════════════
  // COOL OCEAN BREEZE (New)
  // ════════════════════════════════════════════════════════════════════════════

  // Light Mode
  static const Color oceanPrimaryText = Color(0xFF3D5A6C); // Deep Blue-Grey
  static const Color oceanPrimary = Color(0xFF5DA7B1); // Muted Teal
  static const Color oceanBackgroundLight = Color(0xFFF7FBFC); // Pale Sky
  static const Color oceanCardLight = Color(0xFFFFFFFF);
  static const Color oceanAccentLight = Color(0xFFE0F2F1); // Seafoam

  // Dark Mode (Deep Oceanic Depths)
  static const Color oceanBackgroundDark = Color(0xFF0F1A2B); // Deep Navy
  static const Color oceanCardDark = Color(0xFF1C3E61); // Sapphire
  static const Color oceanTextDark = Color(0xFFFFFFFF);
  static const Color oceanAccentDark = Color(0xFF6ECDCF); // Luminous Aquamarine
  static const Color oceanMutedDark = Color(0xFF4CA0B2); // Vibrant Teal

  // ════════════════════════════════════════════════════════════════════════════
  // EARTHY SAGE & STONE (New)
  // ════════════════════════════════════════════════════════════════════════════

  // Light Mode
  static const Color sagePrimaryText = Color(0xFF3C4033); // Warm Charcoal
  static const Color sagePrimary = Color(0xFF7A8266); // Desaturated Olive
  static const Color sageBackgroundLight = Color(0xFFF8F7F2); // Pale Beige
  static const Color sageCardLight = Color(0xFFFFFFFF);
  static const Color sageAccentLight = Color(0xFFE2E4DA); // Soft Sage/Stone

  // Dark Mode (Deep Stone)
  static const Color sageBackgroundDark = Color(0xFF1C1D1A); // Deep Stone
  static const Color sageCardDark = Color(0xFF2A2C26); // Dark Moss/Stone
  static const Color sageTextDark = Color(0xFFE2E4DA); // Sage Light
  static const Color sageAccentDark = Color(0xFF7A8266); // Sage Primary
  static const Color sageMutedDark = Color(0xFFA3A398); // Muted Stone Grey

  // ════════════════════════════════════════════════════════════════════════════
  // LEGACY MAPPINGS (Backward Compatibility)
  // These will always return Lavender/Default colors.
  // Use theme-aware helpers below for dynamic switching.
  // ════════════════════════════════════════════════════════════════════════════
  static const Color primary = primaryText;
  static const Color primaryDark = twilightPale;
  static const Color softLavender = lavenderLight;
  static const Color sageGreen = lavenderSageAccent;
  static const Color sageGreenDark = twilightAccent;
  static const Color offWhite = backgroundLight;
  static const Color whiteText = Color(0xFFF9FAFB);
  static const Color lightText = Color(0xFFF3F4F6);
  static const Color mutedTextDark = Color(0xFF9CA3AF);

  // Status Colors (Shared)
  static const Color orange = Color(0xFFFF8A65);
  static const Color orangeDark = Color(0xFFFFAB91);
  static const Color purple = Color(0xFF7C4DFF);

  static const Color darkText = Color(0xFF131117);
  static const Color mutedText = Color(0xFF94A3B8);

  static const double cardRadius = 24.0;
  static const double spacing = 24.0;

  // ════════════════════════════════════════════════════════════════════════════
  // THEME-AWARE HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  static ThemeVariant _getVariant(BuildContext context) {
    try {
      // Try listening first (standard for build methods)
      return Provider.of<ThemeProvider>(context).currentVariant;
    } catch (e) {
      // If it fails (e.g. called outside widget tree in an event handler), try reading
      try {
        return Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).currentVariant;
      } catch (_) {
        return ThemeVariant.lavender; // Ultimate fallback
      }
    }
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Main brand color
  static Color getPrimary(BuildContext context) {
    final variant = _getVariant(context);
    final dark = isDark(context);

    if (variant == ThemeVariant.sunrise) {
      // In Light Sunrise, it's Muted Apricot (#D48C70)
      return dark ? sunriseAccentDark : sunrisePrimary;
    } else if (variant == ThemeVariant.ocean) {
      return dark ? oceanAccentDark : oceanPrimary;
    } else if (variant == ThemeVariant.sage) {
      return dark ? sageAccentDark : sagePrimary;
    }
    // Default Lavender
    return dark ? twilightAccent : lavenderPrimary;
  }

  /// Main text color
  static Color getTextColor(BuildContext context) {
    final variant = _getVariant(context);
    final dark = isDark(context);

    if (variant == ThemeVariant.sunrise) {
      return dark ? sunriseTextDark : sunrisePrimaryText;
    } else if (variant == ThemeVariant.ocean) {
      return dark ? oceanTextDark : oceanPrimaryText;
    } else if (variant == ThemeVariant.sage) {
      return dark ? sageTextDark : sagePrimaryText;
    }
    return dark ? twilightPale : primaryText;
  }

  /// Secondary/Muted text color
  static Color getMutedColor(BuildContext context) {
    final variant = _getVariant(context);
    final dark = isDark(context);

    if (variant == ThemeVariant.sunrise) {
      return dark
          ? sunriseMutedDark
          : sunrisePrimaryText.withValues(alpha: 0.7);
    } else if (variant == ThemeVariant.ocean) {
      return dark
          ? oceanAccentDark.withValues(alpha: 0.7)
          : oceanPrimaryText.withValues(alpha: 0.7);
    } else if (variant == ThemeVariant.sage) {
      return dark ? sageMutedDark : sagePrimaryText.withValues(alpha: 0.7);
    }
    return dark
        ? skyHaze.withValues(alpha: 0.7)
        : primaryText.withValues(alpha: 0.6);
  }

  static Color getOrangeColor(BuildContext context) =>
      isDark(context) ? orangeDark : orange;

  /// Background color
  static Color getBackground(BuildContext context) {
    final variant = _getVariant(context);
    final dark = isDark(context);

    if (variant == ThemeVariant.sunrise) {
      return dark ? sunriseBackgroundDark : sunriseBackgroundLight;
    } else if (variant == ThemeVariant.ocean) {
      return dark ? oceanBackgroundDark : oceanBackgroundLight;
    } else if (variant == ThemeVariant.sage) {
      return dark ? sageBackgroundDark : sageBackgroundLight;
    }
    return dark ? backgroundDark : backgroundLight;
  }

  /// Card surface color
  static Color getCardColor(BuildContext context) {
    final variant = _getVariant(context);
    final dark = isDark(context);

    if (variant == ThemeVariant.sunrise) {
      return dark ? sunriseCardDark : sunriseCardLight;
    } else if (variant == ThemeVariant.ocean) {
      return dark ? oceanCardDark : oceanCardLight;
    } else if (variant == ThemeVariant.sage) {
      return dark ? sageCardDark : sageCardLight;
    }
    return dark ? cardDark : cardLight;
  }

  /// Icon background color
  static Color getIconBgColor(BuildContext context) {
    final variant = _getVariant(context);
    final dark = isDark(context);

    if (variant == ThemeVariant.sunrise) {
      return dark
          ? sunriseAccentDark.withValues(alpha: 0.2)
          : sunriseAccentLight;
    } else if (variant == ThemeVariant.ocean) {
      return dark ? oceanAccentDark.withValues(alpha: 0.2) : oceanAccentLight;
    } else if (variant == ThemeVariant.sage) {
      return dark ? sageAccentDark.withValues(alpha: 0.2) : sageAccentLight;
    }
    return dark
        ? twilightAccent.withValues(alpha: 0.2)
        : lavenderLight.withValues(alpha: 0.5);
  }

  /// Featured card color (Sage for Insight) OR Sunrise Accent
  static Color getSageColor(BuildContext context) {
    final variant = _getVariant(context);
    final dark = isDark(context);

    if (variant == ThemeVariant.sunrise) {
      return dark ? sunriseAccentDark : sunrisePrimary;
    } else if (variant == ThemeVariant.ocean) {
      return dark ? oceanAccentDark : oceanPrimary;
    } else if (variant == ThemeVariant.sage) {
      return dark ? sageAccentDark : sagePrimary;
    }
    return dark ? twilightAccent : lavenderSageAccent;
  }

  /// Lavender accent color OR Sunrise secondary
  static Color getLavenderColor(BuildContext context) {
    final variant = _getVariant(context);
    final dark = isDark(context);

    if (variant == ThemeVariant.sunrise) {
      return dark
          ? sunriseAccentDark.withValues(alpha: 0.1)
          : const Color(0xFFFFF9F3); // Sunrise "Concept" Light BG
    } else if (variant == ThemeVariant.ocean) {
      return dark ? oceanAccentDark.withValues(alpha: 0.1) : oceanAccentLight;
    } else if (variant == ThemeVariant.sage) {
      return dark ? sageAccentDark.withValues(alpha: 0.1) : sageAccentLight;
    }
    return dark ? twilightAccent.withValues(alpha: 0.1) : lavenderAccent;
  }

  static Color getBorderColor(BuildContext context) {
    final variant = _getVariant(context);
    final dark = isDark(context);

    if (variant == ThemeVariant.sunrise) {
      return dark
          ? Colors.white.withValues(alpha: 0.05)
          : sunrisePrimary.withValues(alpha: 0.2);
    } else if (variant == ThemeVariant.ocean) {
      return dark
          ? Colors.white.withValues(alpha: 0.05)
          : oceanPrimary.withValues(alpha: 0.2);
    } else if (variant == ThemeVariant.sage) {
      return dark
          ? Colors.white.withValues(alpha: 0.05)
          : sagePrimary.withValues(alpha: 0.2);
    }

    return dark
        ? Colors.white.withValues(alpha: 0.05)
        : lavenderLight.withValues(alpha: 0.5);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DECORATIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Main Card Style
  static BoxDecoration getCardDecoration(BuildContext context) => BoxDecoration(
    color: getCardColor(context),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: getBorderColor(context)),
    boxShadow: isDark(context)
        ? null
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
  );

  /// Featured Card Style (Up Next)
  static BoxDecoration getFeaturedCardDecoration(BuildContext context) {
    final variant = _getVariant(context);
    final dark = isDark(context);

    if (variant == ThemeVariant.sunrise) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  const Color(0xFF3D2F28), // Dusk Sepia
                  const Color(0xFF261E1A), // Dusk Charcoal
                ] // Rich Desert Dusk Gradient
              : [
                  const Color(0xFFFFF4D6),
                  const Color(0xFFFFE5D4),
                ], // Light Sunrise
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (dark ? const Color(0xFF8E4C3D) : const Color(0xFFFFE5D4))
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );
    } else if (variant == ThemeVariant.ocean) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  const Color(0xFF1C3E61), // Sapphire
                  const Color(0xFF1B6D7A), // Teal
                ] // Deep Oceanic Gradient
              : [
                  const Color(0xFFBAE6FD), // Light Blue
                  const Color(0xFFB2EBF2), // Cyan
                ], // Light Ocean
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (dark ? const Color(0xFF6ECDCF) : const Color(0xFFB2EBF2))
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );
    } else if (variant == ThemeVariant.sage) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  const Color(0xFF3C4033), // Dark Olive (Warm Charcoal)
                  const Color(0xFF2A2C26), // Dark Stone
                ] // Deep Sage Gradient
              : [
                  const Color(0xFFD4D9C7), // Light Olive
                  const Color(0xFFC2C5BB), // Light Stone
                ], // Light Sage
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (dark ? const Color(0xFF7A8266) : const Color(0xFFC2C5BB))
                .withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }

    // Default Lavender
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [
                const Color(0xFF3B384D),
                const Color(0xFF2D2A3D),
              ] // Dark Lavender
            : [
                const Color(0xFFE0E7FF),
                const Color(0xFFD8D2FF),
              ], // Light Lavender
      ),
      borderRadius: BorderRadius.circular(32),
      boxShadow: [
        BoxShadow(
          color: (dark ? Colors.black : const Color(0xFFD8D2FF)).withValues(
            alpha: 0.3,
          ),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  // Legacy/Alias for Up Next Card
  static BoxDecoration getSageCardDecoration(BuildContext context) =>
      getFeaturedCardDecoration(context);

  static BoxDecoration getLavenderCardDecoration(BuildContext context) =>
      BoxDecoration(
        color: getLavenderColor(context),
        borderRadius: BorderRadius.circular(24),
        border: isDark(context)
            ? Border.all(color: Colors.white.withValues(alpha: 0.05))
            : Border.all(color: getBorderColor(context)),
      );

  // ════════════════════════════════════════════════════════════════════════════
  // THEME DATA DEFINITIONS
  // ════════════════════════════════════════════════════════════════════════════

  // Note: These static getters define the INITIAL theme data.
  // Dynamic color switching happens via the helper methods above.

  static ThemeData lightTheme(ThemeVariant variant) {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();
    Color bg, primary, text;

    if (variant == ThemeVariant.sunrise) {
      bg = sunriseBackgroundLight;
      primary = sunrisePrimary;
      text = sunrisePrimaryText;
    } else if (variant == ThemeVariant.ocean) {
      bg = oceanBackgroundLight;
      primary = oceanPrimary;
      text = oceanPrimaryText;
    } else if (variant == ThemeVariant.sage) {
      bg = sageBackgroundLight;
      primary = sagePrimary;
      text = sagePrimaryText;
    } else {
      bg = backgroundLight;
      primary = lavenderPrimary;
      text = primaryText;
    }

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: primary.withValues(alpha: 0.2),
        surface: bg,
      ),
      iconTheme: IconThemeData(color: text),
      textTheme: _buildTextTheme(baseTextTheme, text),
    );
  }

  static ThemeData darkTheme(ThemeVariant variant) {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();
    Color bg, card, primary, text;

    if (variant == ThemeVariant.sunrise) {
      bg = sunriseBackgroundDark;
      card = sunriseCardDark;
      primary = sunriseAccentDark;
      text = sunriseTextDark;
    } else if (variant == ThemeVariant.ocean) {
      bg = oceanBackgroundDark;
      card = oceanCardDark;
      primary = oceanAccentDark;
      text = oceanTextDark;
    } else if (variant == ThemeVariant.sage) {
      bg = sageBackgroundDark;
      card = sageCardDark;
      primary = sageAccentDark;
      text = sageTextDark;
    } else {
      bg = backgroundDark;
      card = cardDark;
      primary = twilightAccent;
      text = twilightPale;
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      cardColor: card,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: bg,
        onPrimary: bg,
        onSecondary: bg,
        onSurface: text,
      ),
      iconTheme: IconThemeData(
        color: variant == ThemeVariant.sunrise
            ? sunriseMutedDark
            : variant == ThemeVariant.ocean
            ? oceanMutedDark
            : variant == ThemeVariant.sage
            ? sageMutedDark
            : skyHaze,
      ),
      dividerColor: Colors.white.withValues(alpha: 0.1),
      textTheme: _buildTextTheme(baseTextTheme, text),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, Color color) {
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: color,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color.withValues(alpha: 0.8),
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color.withValues(alpha: 0.7),
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: color.withValues(alpha: 0.6),
      ),
    );
  }
}
