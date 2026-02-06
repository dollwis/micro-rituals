import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available theme variants
enum ThemeVariant {
  lavender, // Original
  sunrise, // Warm/Terracotta
  ocean, // Cool/Teal
  sage, // Earthy/Olive
}

/// Theme provider for managing dark/light mode and color variants
class ThemeProvider extends ChangeNotifier {
  static const String _keyZenMode = 'zen_mode';
  static const String _keyVariant = 'theme_variant';

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeVariant _currentVariant = ThemeVariant.lavender;
  ThemeVariant get currentVariant => _currentVariant;

  ThemeProvider();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_keyZenMode) ?? false;

    final variantString = prefs.getString(_keyVariant);
    if (variantString != null) {
      _currentVariant = ThemeVariant.values.firstWhere(
        (e) => e.toString() == variantString,
        orElse: () => ThemeVariant.lavender,
      );
    }
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyZenMode, value);
  }

  Future<void> setVariant(ThemeVariant variant) async {
    if (_currentVariant == variant) return;
    _currentVariant = variant;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVariant, variant.toString());
  }
}
