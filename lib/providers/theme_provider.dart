import 'dart:async';
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

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  ThemeProvider();

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_keyZenMode) ?? false;

      final variantString = prefs.getString(_keyVariant);
      if (variantString != null) {
        _currentVariant = ThemeVariant.values.firstWhere(
          (e) => e.toString() == variantString,
          orElse: () => ThemeVariant.lavender,
        );
      }
    } catch (e) {
      debugPrint('Error loading theme preferences: $e');
      // Fallback to defaults (already set)
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyZenMode, value);
  }

  Timer? _saveTimer;

  Future<void> setVariant(ThemeVariant variant) async {
    if (_currentVariant == variant) return;
    _currentVariant = variant;
    notifyListeners();

    // Debounce saving to SharedPreferences
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyVariant, variant.toString());
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
