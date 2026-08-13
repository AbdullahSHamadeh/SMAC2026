import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppPreferences {
  const AppPreferences({
    this.locale = const Locale('en'),
    this.themeMode = ThemeMode.light,
  });

  final Locale locale;
  final ThemeMode themeMode;

  AppPreferences copyWith({Locale? locale, ThemeMode? themeMode}) {
    return AppPreferences(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

abstract interface class AppPreferencesStore {
  AppPreferences get value;

  Future<void> saveLocale(Locale locale);

  Future<void> saveThemeMode(ThemeMode themeMode);
}

class MemoryAppPreferencesStore implements AppPreferencesStore {
  MemoryAppPreferencesStore([this._value = const AppPreferences()]);

  AppPreferences _value;

  @override
  AppPreferences get value => _value;

  @override
  Future<void> saveLocale(Locale locale) async {
    _value = _value.copyWith(locale: locale);
  }

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    _value = _value.copyWith(themeMode: themeMode);
  }
}

class SharedPreferencesAppPreferencesStore implements AppPreferencesStore {
  SharedPreferencesAppPreferencesStore._(
    this._preferences,
    this._value,
  );

  static const _localeKey = 'family_compass.locale';
  static const _themeModeKey = 'family_compass.theme_mode';

  final SharedPreferences _preferences;
  AppPreferences _value;

  static Future<SharedPreferencesAppPreferencesStore> create() async {
    final preferences = await SharedPreferences.getInstance();
    final languageCode = preferences.getString(_localeKey);
    final savedThemeMode = preferences.getString(_themeModeKey);
    return SharedPreferencesAppPreferencesStore._(
      preferences,
      AppPreferences(
        locale: Locale(languageCode == 'ar' ? 'ar' : 'en'),
        themeMode: savedThemeMode == ThemeMode.dark.name
            ? ThemeMode.dark
            : ThemeMode.light,
      ),
    );
  }

  @override
  AppPreferences get value => _value;

  @override
  Future<void> saveLocale(Locale locale) async {
    _value = _value.copyWith(locale: locale);
    await _preferences.setString(_localeKey, locale.languageCode);
  }

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    _value = _value.copyWith(themeMode: themeMode);
    await _preferences.setString(_themeModeKey, themeMode.name);
  }
}
