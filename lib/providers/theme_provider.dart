import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/accounts_provider.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  ThemeModeNotifier(this._prefs) : super(ThemeMode.dark) {
    _load();
  }

  void _load() {
    final modeIndex = _prefs.getInt(_key);
    if (modeIndex != null) {
      state = ThemeMode.values[modeIndex];
    }
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    await _prefs.setInt(_key, newMode.index);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setInt(_key, mode.index);
  }
}
