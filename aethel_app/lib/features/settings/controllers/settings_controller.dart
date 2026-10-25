import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({
    required this.themeMode,
    required this.autoLockMinutes,
    required this.biometricUnlock,
  });

  final ThemeMode themeMode;
  final int autoLockMinutes;
  final bool biometricUnlock;

  SettingsState copyWith({
    ThemeMode? themeMode,
    int? autoLockMinutes,
    bool? biometricUnlock,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      biometricUnlock: biometricUnlock ?? this.biometricUnlock,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._prefs)
      : super(
          SettingsState(
            themeMode: _themeFrom(_prefs.getString('aethel.theme') ?? 'system'),
            autoLockMinutes: _prefs.getInt('aethel.autolock') ?? 5,
            biometricUnlock: _prefs.getBool('aethel.biometric') ?? true,
          ),
        );

  final SharedPreferences _prefs;

  static ThemeMode _themeFrom(String value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString('aethel.theme', mode.name);
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    state = state.copyWith(autoLockMinutes: minutes);
    await _prefs.setInt('aethel.autolock', minutes);
  }

  Future<void> setBiometricUnlock(bool enabled) async {
    state = state.copyWith(biometricUnlock: enabled);
    await _prefs.setBool('aethel.biometric', enabled);
  }
}
