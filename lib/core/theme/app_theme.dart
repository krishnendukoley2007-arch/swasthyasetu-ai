import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AppTheme {
  const AppTheme();

  static const Color primaryGreen = Color(0xFF006D32);
  static const Color primaryGreenLight = Color(0xFF2E7D32);
  static const Color primaryGreenDark = Color(0xFF004B23);
  static const Color primaryGreenContainer = Color(0xFFBBF3D0);
  static const Color onPrimaryGreenContainer = Color(0xFF00210E);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color accentRed = Color(0xFFC62828);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF1F8F3);
  static const Color textPrimary = Color(0xFF1A1D1A);
  static const Color textSecondary = Color(0xFF5E6A5E);
  static const Color dividerColor = Color(0xFFE0E8E3);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color errorRed = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);
  static const Color successGreen = Color(0xFF006D32);
  static const Color warningAmber = Color(0xFF8C5000);
  static const Color infoBlue = Color(0xFF006874);

  // ── Triage band colours ──
  // Deliberately not the same as the brand greens. A health worker reads these
  // in direct sunlight, so each is dark enough to hold a 4.5:1 contrast ratio
  // against its container and against white. Yellow is a dark amber rather than
  // a literal yellow for exactly that reason — pure yellow text is unreadable
  // outdoors. Never use hue alone to convey the band: pair with the icon and
  // label from `RiskStyle`, because red/green confusion affects ~8% of men.
  static const Color riskGreen = Color(0xFF1B6B3A);
  static const Color riskGreenContainer = Color(0xFFD3F0DE);
  static const Color riskYellow = Color(0xFF8A5300);
  static const Color riskYellowContainer = Color(0xFFFFEBC7);
  static const Color riskRed = Color(0xFFB3261E);
  static const Color riskRedContainer = Color(0xFFFFDAD6);

  static const Color secondaryTeal = Color(0xFF006A6C);
  static const Color secondaryTealContainer = Color(0xFFA6F0F0);
  static const Color onSecondaryTealContainer = Color(0xFF002020);

  static const Color tertiaryAmber = Color(0xFF8C5000);
  static const Color tertiaryAmberContainer = Color(0xFFFFDCB3);
  static const Color onTertiaryAmberContainer = Color(0xFF2E1800);

  static const Color surfaceVariantLight = Color(0xFFDCE8E2);
  static const Color onSurfaceVariantLight = Color(0xFF3F4A43);
  static const Color outlineLight = Color(0xFF707A74);
  static const Color outlineVariantLight = Color(0xFFC0CAC4);

  static const Color surfaceLight = Color(0xFFFAFDFA);
  static const Color onSurfaceLight = Color(0xFF1A1D1A);
  static const Color onBackgroundLight = Color(0xFF1A1D1A);

  static const Color surfaceDark = Color(0xFF1A1D1A);
  static const Color onSurfaceDark = Color(0xFFE4E8E4);
  static const Color backgroundDark = Color(0xFF151815);
  static const Color onBackgroundDark = Color(0xFFE4E8E4);
  static const Color surfaceVariantDark = Color(0xFF3F4A43);
  static const Color onSurfaceVariantDark = Color(0xFFC0CAC4);
  static const Color outlineDark = Color(0xFF8A948E);
  static const Color outlineVariantDark = Color(0xFF3F4A43);

  static const Color inverseSurfaceLight = Color(0xFF2E312F);
  static const Color inverseOnSurfaceLight = Color(0xFFF0F3F0);
  static const Color inversePrimaryLight = Color(0xFFA0D6B3);

  static const Color inverseSurfaceDark = Color(0xFFE4E8E4);
  static const Color inverseOnSurfaceDark = Color(0xFF2E312F);
  static const Color inversePrimaryDark = Color(0xFF006D32);

  static const Color shadowColor = Color(0xFF000000);
  static const Color scrimColor = Color(0xFF000000);

  static const Color glassLight = Color(0x80FFFFFF);
  static const Color glassDark = Color(0x801A1D1A);
  static const Color glassBorderLight = Color(0x33FFFFFF);
  static const Color glassBorderDark = Color(0x33FFFFFF);

  static const double spacingXxs = 2.0;
  /// Bundled Inter, for every string in the app.
  ///
  /// Named explicitly rather than left to the platform default: an OEM skin is
  /// free to map the default sans to a rounded or condensed face, and "94%" in a
  /// decorative typeface is a vital sign a worker can misread. Inter ships in the
  /// APK so the rendering is identical on every phone, online or not.
  static const String fontFamilySans = 'Inter';

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
  static const double spacingXxxl = 64.0;

  static const double radiusXxs = 2.0;
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusXxl = 32.0;
  static const double radiusFull = 9999.0;

  static const double elevationLevel0 = 0.0;
  static const double elevationLevel1 = 1.0;
  static const double elevationLevel2 = 3.0;
  static const double elevationLevel3 = 6.0;
  static const double elevationLevel4 = 12.0;
  static const double elevationLevel5 = 24.0;

  static const Duration durationXs = Duration(milliseconds: 50);
  static const Duration durationSm = Duration(milliseconds: 150);
  static const Duration durationMd = Duration(milliseconds: 300);
  static const Duration durationLg = Duration(milliseconds: 500);
  static const Duration durationXl = Duration(milliseconds: 800);
  static const Duration durationXxl = Duration(milliseconds: 1200);

  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveDecelerate = Curves.easeOutCubic;
  static const Curve curveAccelerate = Curves.easeInCubic;
  static const Curve curveSharp = Curves.easeInOutQuad;
  static const Curve curveBounce = Curves.elasticOut;
  static const Curve curveSpring = Curves.bounceOut;

  static const List<BoxShadow> shadowLevel1 = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowLevel2 = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowLevel3 = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowLevel4 = [
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> shadowLevel5 = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 48,
      offset: Offset(0, 24),
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> shadowColoredPrimary = [
    BoxShadow(
      color: Color(0x4C006D32),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x26006D32),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowColoredError = [
    BoxShadow(
      color: Color(0x4CBA1A1A),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x26BA1A1A),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowGlowPrimary = [
    BoxShadow(
      color: Color(0x66006D32),
      blurRadius: 24,
      offset: Offset(0, 0),
    ),
    BoxShadow(
      color: Color(0x33006D32),
      blurRadius: 12,
      offset: Offset(0, 0),
    ),
  ];

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: primaryGreenContainer,
      onPrimaryContainer: onPrimaryGreenContainer,
      secondary: secondaryTeal,
      onSecondary: Colors.white,
      secondaryContainer: secondaryTealContainer,
      onSecondaryContainer: onSecondaryTealContainer,
      tertiary: tertiaryAmber,
      onTertiary: Colors.white,
      tertiaryContainer: tertiaryAmberContainer,
      onTertiaryContainer: onTertiaryAmberContainer,
      error: errorRed,
      onError: Colors.white,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surfaceLight,
      onSurface: onSurfaceLight,
      surfaceContainerHighest: surfaceVariantLight,
      onSurfaceVariant: onSurfaceVariantLight,
      outline: outlineLight,
      outlineVariant: outlineVariantLight,
      shadow: shadowColor,
      scrim: scrimColor,
      inverseSurface: inverseSurfaceLight,
      onInverseSurface: inverseOnSurfaceLight,
      inversePrimary: inversePrimaryLight,
      surfaceTint: primaryGreen,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamilySans,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundLight,
      canvasColor: surfaceLight,
      shadowColor: shadowColor,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        foregroundColor: onSurfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: elevationLevel0,
        scrolledUnderElevation: elevationLevel1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: onSurfaceLight,
          letterSpacing: -0.3,
        ),
        toolbarHeight: 64,
        shape: Border(
          bottom: BorderSide(color: outlineVariantLight, width: 0.5),
        ),
      ),

      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: elevationLevel0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: outlineVariantLight, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: outlineVariantLight,
          disabledForegroundColor: onSurfaceVariantLight.withValues(alpha: 0.38),
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          elevation: elevationLevel0,
          shadowColor: Colors.transparent,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return primaryGreenDark.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return primaryGreenDark.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.focused)) {
                return primaryGreenDark.withValues(alpha: 0.12);
              }
              return null;
            },
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          disabledForegroundColor: onSurfaceVariantLight.withValues(alpha: 0.38),
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingMd),
          side: const BorderSide(color: primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return primaryGreen.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return primaryGreen.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.focused)) {
                return primaryGreen.withValues(alpha: 0.12);
              }
              return null;
            },
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          disabledForegroundColor: onSurfaceVariantLight.withValues(alpha: 0.38),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return primaryGreen.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return primaryGreen.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.focused)) {
                return primaryGreen.withValues(alpha: 0.12);
              }
              return null;
            },
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingMd),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: outlineVariantLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: outlineVariantLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: outlineVariantLight.withValues(alpha: 0.5), width: 1),
        ),
        labelStyle: const TextStyle(
          color: onSurfaceVariantLight,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: TextStyle(
          color: onSurfaceVariantLight.withValues(alpha: 0.5),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: const TextStyle(
          color: errorRed,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: primaryGreen,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: onSurfaceVariantLight.withValues(alpha: 0.5),
        suffixIconColor: onSurfaceVariantLight.withValues(alpha: 0.5),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w300,
          color: onSurfaceLight,
          letterSpacing: -1.5,
          height: 1.12,
        ),
        displayMedium: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w300,
          color: onSurfaceLight,
          letterSpacing: -0.5,
          height: 1.16,
        ),
        displaySmall: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w400,
          color: onSurfaceLight,
          letterSpacing: 0,
          height: 1.22,
        ),
        headlineLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: onSurfaceLight,
          letterSpacing: -0.5,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: onSurfaceLight,
          letterSpacing: 0,
          height: 1.29,
        ),
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: onSurfaceLight,
          letterSpacing: 0,
          height: 1.33,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: onSurfaceLight,
          letterSpacing: 0,
          height: 1.27,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurfaceLight,
          letterSpacing: 0.15,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: onSurfaceLight,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: onSurfaceLight,
          letterSpacing: 0.3,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: onSurfaceLight,
          letterSpacing: 0.2,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariantLight,
          letterSpacing: 0.3,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: onSurfaceLight,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: onSurfaceVariantLight,
          letterSpacing: 0.5,
          height: 1.33,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: onSurfaceVariantLight,
          letterSpacing: 0.5,
          height: 1.45,
        ),
      ),

      iconTheme: const IconThemeData(
        color: onSurfaceVariantLight,
        size: 24,
        fill: 0,
        weight: 400,
        grade: 0,
        opticalSize: 24,
      ),

      dividerTheme: const DividerThemeData(
        color: outlineVariantLight,
        thickness: 0.5,
        space: 1,
        indent: spacingMd,
        endIndent: spacingMd,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariantLight.withValues(alpha: 0.3),
        disabledColor: surfaceVariantLight.withValues(alpha: 0.15),
        selectedColor: primaryGreenContainer,
        secondarySelectedColor: secondaryTealContainer,
        labelStyle: const TextStyle(
          color: onSurfaceLight,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: onPrimaryGreenContainer,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: spacingSm, vertical: spacingXs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
          side: const BorderSide(color: outlineVariantLight, width: 0.5),
        ),
        side: const BorderSide(color: outlineVariantLight, width: 0.5),
        brightness: Brightness.light,
        elevation: elevationLevel0,
        pressElevation: elevationLevel1,
        checkmarkColor: primaryGreen,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primaryGreen,
        unselectedItemColor: onSurfaceVariantLight,
        type: BottomNavigationBarType.fixed,
        elevation: elevationLevel3,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceLight,
        indicatorColor: primaryGreenContainer,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryGreen,
              );
            }
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: onSurfaceVariantLight,
            );
          },
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: primaryGreen,
                size: 26,
                fill: 1,
              );
            }
            return const IconThemeData(
              color: onSurfaceVariantLight,
              size: 26,
              fill: 0,
            );
          },
        ),
        height: 80,
        elevation: elevationLevel3,
        shadowColor: shadowColor.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: elevationLevel3,
        focusElevation: elevationLevel4,
        hoverElevation: elevationLevel4,
        highlightElevation: elevationLevel5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        extendedTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: elevationLevel0,
        shadowColor: shadowColor.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurfaceLight,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariantLight,
          height: 1.5,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: elevationLevel0,
        shadowColor: shadowColor.withValues(alpha: 0.15),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXxl)),
        ),
        modalBackgroundColor: surfaceLight,
        constraints: const BoxConstraints(minWidth: double.infinity),
        dragHandleColor: outlineVariantLight,
        dragHandleSize: const Size(36, 4),
        showDragHandle: true,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurfaceLight.withValues(alpha: 0.92),
        contentTextStyle: const TextStyle(
          color: surfaceLight,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        actionTextColor: tertiaryAmberContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: elevationLevel3,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: onSurfaceLight.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(
          color: surfaceLight,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
        verticalOffset: 24,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGreen,
        linearTrackColor: surfaceVariantLight,
        circularTrackColor: surfaceVariantLight,
        refreshBackgroundColor: surfaceVariantLight,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: primaryGreen,
        inactiveTrackColor: surfaceVariantLight,
        thumbColor: primaryGreen,
        overlayColor: primaryGreen.withValues(alpha: 0.12),
        valueIndicatorColor: primaryGreen,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        activeTickMarkColor: primaryGreen,
        inactiveTickMarkColor: outlineVariantLight,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: primaryGreen,
        unselectedLabelColor: onSurfaceVariantLight,
        indicatorColor: primaryGreen,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(radiusSm),
          color: primaryGreenContainer,
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.pressed)) {
              return primaryGreen.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return primaryGreen.withValues(alpha: 0.08);
            }
            return null;
          },
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingXs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        tileColor: Colors.transparent,
        selectedTileColor: primaryGreenContainer,
        iconColor: onSurfaceVariantLight,
        textColor: onSurfaceLight,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: onSurfaceLight,
          height: 1.3,
        ),
        subtitleTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariantLight,
          height: 1.3,
        ),
        leadingAndTrailingTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariantLight,
        ),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(surfaceLight),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(elevationLevel3),
          shadowColor: WidgetStatePropertyAll(shadowColor.withValues(alpha: 0.15)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: spacingSm)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: elevationLevel3,
        shadowColor: shadowColor.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurfaceLight,
        ),
      ),

      dividerColor: outlineVariantLight,
      focusColor: primaryGreen.withValues(alpha: 0.12),
      hoverColor: primaryGreen.withValues(alpha: 0.08),
      highlightColor: primaryGreen.withValues(alpha: 0.12),
      splashColor: primaryGreen.withValues(alpha: 0.15),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF80D6A3),
      onPrimary: Color(0xFF001207),
      primaryContainer: primaryGreenDark,
      onPrimaryContainer: primaryGreenContainer,
      secondary: secondaryTeal,
      onSecondary: Color(0xFF001212),
      secondaryContainer: secondaryTeal,
      onSecondaryContainer: secondaryTealContainer,
      tertiary: tertiaryAmber,
      onTertiary: Color(0xFF1F1100),
      tertiaryContainer: tertiaryAmber,
      onTertiaryContainer: tertiaryAmberContainer,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: errorContainer,
      surface: surfaceDark,
      onSurface: onSurfaceDark,
      surfaceContainerHighest: surfaceVariantDark,
      onSurfaceVariant: onSurfaceVariantDark,
      outline: outlineDark,
      outlineVariant: outlineVariantDark,
      shadow: shadowColor,
      scrim: scrimColor,
      inverseSurface: inverseSurfaceDark,
      onInverseSurface: inverseOnSurfaceDark,
      inversePrimary: inversePrimaryDark,
      surfaceTint: Color(0xFF80D6A3),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamilySans,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundDark,
      canvasColor: surfaceDark,
      shadowColor: shadowColor,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: onSurfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: elevationLevel0,
        scrolledUnderElevation: elevationLevel1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: onSurfaceDark,
          letterSpacing: -0.3,
        ),
        toolbarHeight: 64,
        shape: Border(
          bottom: BorderSide(color: outlineVariantDark, width: 0.5),
        ),
      ),

      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: elevationLevel0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: outlineVariantDark, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF80D6A3),
          foregroundColor: const Color(0xFF001207),
          disabledBackgroundColor: outlineVariantDark,
          disabledForegroundColor: onSurfaceVariantDark.withValues(alpha: 0.38),
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          elevation: elevationLevel0,
          shadowColor: Colors.transparent,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return const Color(0xFF006D32).withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFF006D32).withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.focused)) {
                return const Color(0xFF006D32).withValues(alpha: 0.12);
              }
              return null;
            },
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF80D6A3),
          foregroundColor: const Color(0xFF001207),
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF80D6A3),
          disabledForegroundColor: onSurfaceVariantDark.withValues(alpha: 0.38),
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: spacingLg, vertical: spacingMd),
          side: const BorderSide(color: Color(0xFF80D6A3), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return const Color(0xFF80D6A3).withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFF80D6A3).withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.focused)) {
                return const Color(0xFF80D6A3).withValues(alpha: 0.12);
              }
              return null;
            },
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF80D6A3),
          disabledForegroundColor: onSurfaceVariantDark.withValues(alpha: 0.38),
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.pressed)) {
                return const Color(0xFF80D6A3).withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFF80D6A3).withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.focused)) {
                return const Color(0xFF80D6A3).withValues(alpha: 0.12);
              }
              return null;
            },
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingMd),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: outlineVariantDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: outlineVariantDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: Color(0xFF80D6A3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: Color(0xFFFFB4AB), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: Color(0xFFFFB4AB), width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: outlineVariantDark.withValues(alpha: 0.5), width: 1),
        ),
        labelStyle: const TextStyle(
          color: onSurfaceVariantDark,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: TextStyle(
          color: onSurfaceVariantDark.withValues(alpha: 0.5),
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: const TextStyle(
          color: Color(0xFFFFB4AB),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF80D6A3),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: onSurfaceVariantDark.withValues(alpha: 0.5),
        suffixIconColor: onSurfaceVariantDark.withValues(alpha: 0.5),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.w300,
          color: onSurfaceDark,
          letterSpacing: -1.5,
          height: 1.12,
        ),
        displayMedium: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w300,
          color: onSurfaceDark,
          letterSpacing: -0.5,
          height: 1.16,
        ),
        displaySmall: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w400,
          color: onSurfaceDark,
          letterSpacing: 0,
          height: 1.22,
        ),
        headlineLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: onSurfaceDark,
          letterSpacing: -0.5,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: onSurfaceDark,
          letterSpacing: 0,
          height: 1.29,
        ),
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: onSurfaceDark,
          letterSpacing: 0,
          height: 1.33,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: onSurfaceDark,
          letterSpacing: 0,
          height: 1.27,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurfaceDark,
          letterSpacing: 0.15,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: onSurfaceDark,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: onSurfaceDark,
          letterSpacing: 0.3,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: onSurfaceDark,
          letterSpacing: 0.2,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariantDark,
          letterSpacing: 0.3,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: onSurfaceDark,
          letterSpacing: 0.1,
          height: 1.43,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: onSurfaceVariantDark,
          letterSpacing: 0.5,
          height: 1.33,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: onSurfaceVariantDark,
          letterSpacing: 0.5,
          height: 1.45,
        ),
      ),

      iconTheme: const IconThemeData(
        color: onSurfaceVariantDark,
        size: 24,
        fill: 0,
        weight: 400,
        grade: 0,
        opticalSize: 24,
      ),

      dividerTheme: const DividerThemeData(
        color: outlineVariantDark,
        thickness: 0.5,
        space: 1,
        indent: spacingMd,
        endIndent: spacingMd,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariantDark.withValues(alpha: 0.3),
        disabledColor: surfaceVariantDark.withValues(alpha: 0.15),
        selectedColor: primaryGreenDark,
        secondarySelectedColor: secondaryTeal,
        labelStyle: const TextStyle(
          color: onSurfaceDark,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: onPrimaryGreenContainer,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: spacingSm, vertical: spacingXs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
          side: const BorderSide(color: outlineVariantDark, width: 0.5),
        ),
        side: const BorderSide(color: outlineVariantDark, width: 0.5),
        brightness: Brightness.dark,
        elevation: elevationLevel0,
        pressElevation: elevationLevel1,
        checkmarkColor: const Color(0xFF80D6A3),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: Color(0xFF80D6A3),
        unselectedItemColor: onSurfaceVariantDark,
        type: BottomNavigationBarType.fixed,
        elevation: elevationLevel3,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark,
        indicatorColor: primaryGreenDark,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF80D6A3),
              );
            }
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: onSurfaceVariantDark,
            );
          },
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: Color(0xFF80D6A3),
                size: 26,
                fill: 1,
              );
            }
            return const IconThemeData(
              color: onSurfaceVariantDark,
              size: 26,
              fill: 0,
            );
          },
        ),
        height: 80,
        elevation: elevationLevel3,
        shadowColor: shadowColor.withValues(alpha: 0.3),
        surfaceTintColor: Colors.transparent,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF80D6A3),
        foregroundColor: const Color(0xFF001207),
        elevation: elevationLevel3,
        focusElevation: elevationLevel4,
        hoverElevation: elevationLevel4,
        highlightElevation: elevationLevel5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFull),
        ),
        extendedTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: elevationLevel0,
        shadowColor: shadowColor.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurfaceDark,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariantDark,
          height: 1.5,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: elevationLevel0,
        shadowColor: shadowColor.withValues(alpha: 0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXxl)),
        ),
        modalBackgroundColor: surfaceDark,
        constraints: const BoxConstraints(minWidth: double.infinity),
        dragHandleColor: outlineVariantDark,
        dragHandleSize: const Size(36, 4),
        showDragHandle: true,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurfaceDark.withValues(alpha: 0.92),
        contentTextStyle: const TextStyle(
          color: surfaceDark,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        actionTextColor: tertiaryAmberContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: elevationLevel3,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: onSurfaceDark.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(
          color: surfaceDark,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        padding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingSm),
        verticalOffset: 24,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF80D6A3),
        linearTrackColor: surfaceVariantDark,
        circularTrackColor: surfaceVariantDark,
        refreshBackgroundColor: surfaceVariantDark,
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: const Color(0xFF80D6A3),
        inactiveTrackColor: surfaceVariantDark,
        thumbColor: const Color(0xFF80D6A3),
        overlayColor: const Color(0xFF80D6A3).withValues(alpha: 0.12),
        valueIndicatorColor: const Color(0xFF80D6A3),
        valueIndicatorTextStyle: const TextStyle(color: Color(0xFF001207), fontSize: 12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        activeTickMarkColor: const Color(0xFF80D6A3),
        inactiveTickMarkColor: outlineVariantDark,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: const Color(0xFF80D6A3),
        unselectedLabelColor: onSurfaceVariantDark,
        indicatorColor: const Color(0xFF80D6A3),
        indicatorSize: TabBarIndicatorSize.label,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(radiusSm),
          color: primaryGreenDark,
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith<Color?>(
          (states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFF80D6A3).withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFF80D6A3).withValues(alpha: 0.08);
            }
            return null;
          },
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: spacingXs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        tileColor: Colors.transparent,
        selectedTileColor: primaryGreenDark,
        iconColor: onSurfaceVariantDark,
        textColor: onSurfaceDark,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: onSurfaceDark,
          height: 1.3,
        ),
        subtitleTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariantDark,
          height: 1.3,
        ),
        leadingAndTrailingTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariantDark,
        ),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(surfaceDark),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(elevationLevel3),
          shadowColor: WidgetStatePropertyAll(shadowColor.withValues(alpha: 0.3)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: spacingSm)),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: elevationLevel3,
        shadowColor: shadowColor.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurfaceDark,
        ),
      ),

      dividerColor: outlineVariantDark,
      focusColor: const Color(0xFF80D6A3).withValues(alpha: 0.12),
      hoverColor: const Color(0xFF80D6A3).withValues(alpha: 0.08),
      highlightColor: const Color(0xFF80D6A3).withValues(alpha: 0.12),
      splashColor: const Color(0xFF80D6A3).withValues(alpha: 0.15),
    );
  }

  /// A higher-contrast variant of any theme, for reading a screen in direct
  /// sunlight.
  ///
  /// Derived from the base theme rather than defined separately, so a colour
  /// added to `lightTheme` or `darkTheme` never silently goes missing here.
  /// The changes are the ones that survive glare: push text and icons to the
  /// extremes of the surface's luminance range, make every border visible
  /// instead of hinted, and drop the tonal fills that reduce edge definition.
  static ThemeData highContrast(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    final ink = isDark ? Colors.white : Colors.black;
    final paper = isDark ? Colors.black : Colors.white;

    final scheme = base.colorScheme.copyWith(
      surface: paper,
      onSurface: ink,
      // Secondary text at full contrast too: at 2.0 text scale in bright light
      // the muted variant is the first thing to become unreadable.
      onSurfaceVariant: ink,
      surfaceContainerHighest: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
      outline: ink,
      outlineVariant: isDark ? const Color(0xFF9E9E9E) : const Color(0xFF616161),
      surfaceTint: Colors.transparent,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      canvasColor: paper,
      dividerColor: scheme.outline,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: paper,
        foregroundColor: ink,
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(color: ink),
        shape: Border(bottom: BorderSide(color: ink, width: 1.5)),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          // A card with no fill contrast needs a real border to read as a card.
          side: BorderSide(color: ink, width: 1.5),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: ink, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 2.5),
        ),
        labelStyle: TextStyle(color: ink),
        hintStyle: TextStyle(color: ink.withValues(alpha: 0.7)),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      iconTheme: base.iconTheme.copyWith(color: ink),
      listTileTheme: base.listTileTheme.copyWith(
        textColor: ink,
        iconColor: ink,
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: ink, width: 1.5),
        labelStyle: base.chipTheme.labelStyle?.copyWith(color: ink),
      ),
    );
  }

  static Color getRiskColor(BuildContext context, String riskLevel) {
    final theme = Theme.of(context);
    switch (riskLevel.toUpperCase()) {
      case 'RED':
      case 'HIGH':
      case 'URGENT':
        return theme.colorScheme.error;
      case 'YELLOW':
      case 'AMBER':
      case 'MEDIUM':
      case 'ATTENTION':
        return theme.colorScheme.tertiary;
      case 'GREEN':
      case 'LOW':
      case 'NORMAL':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  static IconData getRiskIcon(String riskLevel) {
    switch (riskLevel.toUpperCase()) {
      case 'RED':
      case 'HIGH':
      case 'URGENT':
        return Icons.error_outline_rounded;
      case 'YELLOW':
      case 'AMBER':
      case 'MEDIUM':
      case 'ATTENTION':
        return Icons.warning_amber_rounded;
      case 'GREEN':
      case 'LOW':
      case 'NORMAL':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  static Color getRiskContainerColor(BuildContext context, String riskLevel) {
    final theme = Theme.of(context);
    switch (riskLevel.toUpperCase()) {
      case 'RED':
      case 'HIGH':
      case 'URGENT':
        return theme.colorScheme.errorContainer;
      case 'YELLOW':
      case 'AMBER':
      case 'MEDIUM':
      case 'ATTENTION':
        return theme.colorScheme.tertiaryContainer;
      case 'GREEN':
      case 'LOW':
      case 'NORMAL':
        return theme.colorScheme.primaryContainer;
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  static Color getRiskOnContainerColor(BuildContext context, String riskLevel) {
    final theme = Theme.of(context);
    switch (riskLevel.toUpperCase()) {
      case 'RED':
      case 'HIGH':
      case 'URGENT':
        return theme.colorScheme.onErrorContainer;
      case 'YELLOW':
      case 'AMBER':
      case 'MEDIUM':
      case 'ATTENTION':
        return theme.colorScheme.onTertiaryContainer;
      case 'GREEN':
      case 'LOW':
      case 'NORMAL':
        return theme.colorScheme.onPrimaryContainer;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}

extension ThemeExtensions on BuildContext {
  AppTheme get appTheme => const AppTheme();
  
  ColorScheme get colors => Theme.of(this).colorScheme;
  
  TextTheme get text => Theme.of(this).textTheme;
  
  double get spacingXxs => AppTheme.spacingXxs;
  double get spacingXs => AppTheme.spacingXs;
  double get spacingSm => AppTheme.spacingSm;
  double get spacingMd => AppTheme.spacingMd;
  double get spacingLg => AppTheme.spacingLg;
  double get spacingXl => AppTheme.spacingXl;
  double get spacingXxl => AppTheme.spacingXxl;
  double get spacingXxxl => AppTheme.spacingXxxl;

  double get radiusXxs => AppTheme.radiusXxs;
  double get radiusXs => AppTheme.radiusXs;
  double get radiusSm => AppTheme.radiusSm;
  double get radiusMd => AppTheme.radiusMd;
  double get radiusLg => AppTheme.radiusLg;
  double get radiusXl => AppTheme.radiusXl;
  double get radiusXxl => AppTheme.radiusXxl;
  double get radiusFull => AppTheme.radiusFull;

  Duration get durationXs => AppTheme.durationXs;
  Duration get durationSm => AppTheme.durationSm;
  Duration get durationMd => AppTheme.durationMd;
  Duration get durationLg => AppTheme.durationLg;
  Duration get durationXl => AppTheme.durationXl;
  Duration get durationXxl => AppTheme.durationXxl;

  Curve get curveStandard => AppTheme.curveStandard;
  Curve get curveDecelerate => AppTheme.curveDecelerate;
  Curve get curveAccelerate => AppTheme.curveAccelerate;
  Curve get curveSharp => AppTheme.curveSharp;
  Curve get curveBounce => AppTheme.curveBounce;
  Curve get curveSpring => AppTheme.curveSpring;

  List<BoxShadow> get shadow1 => AppTheme.shadowLevel1;
  List<BoxShadow> get shadow2 => AppTheme.shadowLevel2;
  List<BoxShadow> get shadow3 => AppTheme.shadowLevel3;
  List<BoxShadow> get shadow4 => AppTheme.shadowLevel4;
  List<BoxShadow> get shadow5 => AppTheme.shadowLevel5;
  List<BoxShadow> get shadowPrimary => AppTheme.shadowColoredPrimary;
  List<BoxShadow> get shadowError => AppTheme.shadowColoredError;
  List<BoxShadow> get shadowGlowPrimary => AppTheme.shadowGlowPrimary;
}

class AppGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final Color? color;
  final List<BoxShadow>? shadows;
  final bool isDark;

  const AppGlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 20,
    this.color,
    this.shadows,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: color ?? (brightness == Brightness.dark 
                  ? AppTheme.glassDark 
                  : AppTheme.glassLight),
              borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: brightness == Brightness.dark 
                    ? AppTheme.glassBorderDark 
                    : AppTheme.glassBorderLight,
                width: 1,
              ),
              boxShadow: shadows ?? (brightness == Brightness.dark 
                  ? AppTheme.shadowLevel2 
                  : AppTheme.shadowLevel1),
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(AppTheme.spacingMd),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class AppGradientContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final List<BoxShadow>? shadows;

  const AppGradientContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: begin,
            end: end,
          ),
          borderRadius: borderRadius ?? BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: shadows,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppTheme.spacingMd),
          child: child,
        ),
      ),
    );
  }
}