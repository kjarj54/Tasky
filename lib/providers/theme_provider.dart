import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppThemeMode _appThemeMode = AppThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  AppThemeMode get appThemeMode => _appThemeMode;

  Future<void> setTheme(AppThemeMode mode) async {
    _appThemeMode = mode;
    _themeMode = _getThemeModeFromAppThemeMode(mode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('theme_mode') ?? AppThemeMode.system.index;
    _appThemeMode = AppThemeMode.values[index];
    _themeMode = _getThemeModeFromAppThemeMode(_appThemeMode);
    notifyListeners();
  }

  ThemeMode _getThemeModeFromAppThemeMode(AppThemeMode mode) {
    if (mode == AppThemeMode.system) {
      final hour = DateTime.now().hour;
      if (hour >= 18 || hour < 6) {
        return ThemeMode.dark;
      } else {
        return ThemeMode.light;
      }
    } else if (mode == AppThemeMode.dark) {
      return ThemeMode.dark;
    } else {
      return ThemeMode.light;
    }
  }
}