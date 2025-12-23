import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/accounts_provider.dart';

class LogSettings {
  final bool autoScroll;
  final bool showTimestamps;

  LogSettings({required this.autoScroll, required this.showTimestamps});

  LogSettings copyWith({bool? autoScroll, bool? showTimestamps}) {
    return LogSettings(
      autoScroll: autoScroll ?? this.autoScroll,
      showTimestamps: showTimestamps ?? this.showTimestamps,
    );
  }
}

final logSettingsProvider =
    StateNotifierProvider<LogSettingsNotifier, LogSettings>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return LogSettingsNotifier(prefs);
    });

class LogSettingsNotifier extends StateNotifier<LogSettings> {
  final SharedPreferences _prefs;

  LogSettingsNotifier(this._prefs)
    : super(
        LogSettings(
          autoScroll: _prefs.getBool('log_auto_scroll') ?? true,
          showTimestamps: _prefs.getBool('log_show_timestamps') ?? true,
        ),
      );

  void toggleAutoScroll() {
    state = state.copyWith(autoScroll: !state.autoScroll);
    _prefs.setBool('log_auto_scroll', state.autoScroll);
  }

  void toggleTimestamps() {
    state = state.copyWith(showTimestamps: !state.showTimestamps);
    _prefs.setBool('log_show_timestamps', state.showTimestamps);
  }
}
