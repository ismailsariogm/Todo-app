import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Theme Mode ───────────────────────────────────────────────────────────
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ─── Locale ───────────────────────────────────────────────────────────────
class LocaleNotifier extends Notifier<Locale> {
  static const _key = 'app_locale';

  @override
  Locale build() => const Locale('tr');

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    state = (raw == 'en') ? const Locale('en') : const Locale('tr');
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

// ─── Profile Settings ─────────────────────────────────────────────────────
class ProfileSettings {
  const ProfileSettings({
    this.photoUrl,
    this.aboutMe = '',
    this.links = const [],
    this.onlineVisible = true,
    this.readReceipts = true,
  });

  final String? photoUrl;
  final String aboutMe;
  final List<String> links;
  final bool onlineVisible;
  final bool readReceipts;

  ProfileSettings copyWith({
    String? photoUrl,
    String? aboutMe,
    List<String>? links,
    bool? onlineVisible,
    bool? readReceipts,
    bool clearPhoto = false,
  }) {
    return ProfileSettings(
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      aboutMe: aboutMe ?? this.aboutMe,
      links: links ?? this.links,
      onlineVisible: onlineVisible ?? this.onlineVisible,
      readReceipts: readReceipts ?? this.readReceipts,
    );
  }
}

class ProfileNotifier extends Notifier<ProfileSettings> {
  @override
  ProfileSettings build() => const ProfileSettings();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    state = ProfileSettings(
      photoUrl: prefs.getString('profile_photo'),
      aboutMe: prefs.getString('profile_about') ?? '',
      links: prefs.getStringList('profile_links') ?? [],
      onlineVisible: prefs.getBool('profile_online') ?? true,
      readReceipts: prefs.getBool('profile_read_receipts') ?? true,
    );
  }

  Future<void> setPhotoUrl(String? url) async {
    state = state.copyWith(photoUrl: url, clearPhoto: url == null);
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove('profile_photo');
    } else {
      await prefs.setString('profile_photo', url);
    }
  }

  Future<void> setAboutMe(String text) async {
    state = state.copyWith(aboutMe: text);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_about', text);
  }

  Future<void> setLinks(List<String> links) async {
    state = state.copyWith(links: links);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('profile_links', links);
  }

  Future<void> setOnlineVisible(bool value) async {
    state = state.copyWith(onlineVisible: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_online', value);
  }

  Future<void> setReadReceipts(bool value) async {
    state = state.copyWith(readReceipts: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_read_receipts', value);
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileSettings>(
  ProfileNotifier.new,
);
