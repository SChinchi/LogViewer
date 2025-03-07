import 'package:flutter/material.dart';

class AppTheme {
  static const bool _isDarkTheme = true;

  static get primaryColor => _isDarkTheme ? Colors.white : Colors.black;

  static get secondaryColor => _isDarkTheme ? Colors.black : Colors.white;

  static get selectedColor => _isDarkTheme ? Colors.grey[700] : Colors.grey[400];

  static get disabledColor => _isDarkTheme ? Colors.white30 : Colors.black38;

  static get dialogBackgroundColor => _isDarkTheme ? Colors.grey[800] : Colors.grey[200];

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      applyElevationOverlayColor: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: secondaryColor,
        secondary: secondaryColor,
        onSecondary: primaryColor,
        error: Colors.red,
        onError: secondaryColor,
        surface: secondaryColor,
        onSurface: primaryColor,
      ),
      cardTheme: CardThemeData(
        shadowColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      sliderTheme: SliderThemeData(
          inactiveTrackColor: disabledColor
      ),
      textTheme: TextTheme(
        bodySmall: TextStyle(
          color: primaryColor,
        ),
      ),
    );
  }
}