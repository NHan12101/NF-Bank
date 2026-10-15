import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'SFProDisplay';

  static ThemeData get dark {
    return FlexThemeData.dark(
      scheme: FlexScheme.blueM3,
      useMaterial3: true,
      fontFamily: fontFamily,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 12,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 15,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: false,
        alignedDropdown: true,
        inputDecoratorIsFilled: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorUnfocusedHasBorder: true,
        inputDecoratorRadius: 14.0,
        cardRadius: 18.0,
        elevatedButtonRadius: 14.0,
        filledButtonRadius: 14.0,
        outlinedButtonRadius: 14.0,
        textButtonRadius: 14.0,
        dialogRadius: 20.0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      scaffoldBackground: const Color(0xFF0B0D17),
      surface: const Color(0xFF151828),
    );
  }

  static ThemeData get light {
    return FlexThemeData.light(
      scheme: FlexScheme.blueM3,
      useMaterial3: true,
      fontFamily: fontFamily,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        useMaterial3Typography: true,
        useM2StyleDividerInM3: false,
        alignedDropdown: true,
        inputDecoratorIsFilled: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorUnfocusedHasBorder: true,
        inputDecoratorRadius: 14.0,
        cardRadius: 18.0,
        elevatedButtonRadius: 14.0,
        filledButtonRadius: 14.0,
        outlinedButtonRadius: 14.0,
        textButtonRadius: 14.0,
        dialogRadius: 20.0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      scaffoldBackground: const Color(0xFFF3F5FA),
      surface: Colors.white,
    );
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white60
        : Colors.black54;
  }

  static Color textTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white38
        : Colors.black38;
  }

  static Color cardBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: .07)
        : Colors.black.withValues(alpha: .06);
  }
}
