import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/chat_repository.dart';
import '../../domain/entities/chat_user_entity.dart';

// ─── Demo User ────────────────────────────────────────────────────────────────

class DemoUser {
  DemoUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.phone,
    this.countryCode,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoURL;
  final String? phone;      // raw phone number e.g. "555 123 4567"
  final String? countryCode; // e.g. "+90"
}

// ─── User DB helpers ─────────────────────────────────────────────────────────
// All registered users are stored in a single JSON list under the key
// 'users_db'.  This is far more robust than individual per-email keys because
// it survives hot-restarts and avoids key-format mismatches.

const _kUsersDb   = 'users_db';
const _kLastEmail = 'last_signin_email';
const _kLsUsersDb = 'todo_app_users_db';
const _kLsSession = 'todo_app_session';

// Yerel DB sunucusu (tool/db_server.dart) — port 3001
const _kApiBase = 'http://localhost:3001';

typedef _UserRecord = Map<String, dynamic>;

// ─── API yardımcıları ─────────────────────────────────────────────────────────

/// Sunucu erişilebilir mi kontrol eder.
Future<bool> _apiAvailable() async {
  try {
    final res = await http
        .get(Uri.parse('$_kApiBase/health'))
        .timeout(const Duration(seconds: 2));
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

// ─── Kullanıcı DB okuma / yazma (3 katman) ───────────────────────────────────
// 1. API sunucusu (disk dosyası — en kalıcı)
// 2. window.localStorage (browser profili)
// 3. SharedPreferences (flutter.prefix)

List<_UserRecord> _parseList(String raw) {
  if (raw.isEmpty) return [];
  try { return List<_UserRecord>.from(jsonDecode(raw) as List); }
  catch (_) { return []; }
}

/// Birden fazla kaynaktan kullanıcı listesi yükler ve birleştirir.
/// Öncelik: API (veritabanı) > SharedPreferences > localStorage
Future<List<_UserRecord>> _loadUsers() async {
  final combined = <String, _UserRecord>{};

  void absorb(List<_UserRecord> list) {
    for (final u in list) {
      final e = (u['email'] as String?)?.trim().toLowerCase() ?? '';
      if (e.isNotEmpty) combined[e] = u;
    }
  }

  // Kaynak 1 — Yerel API sunucusu (veritabanı, birincil kaynak)
  try {
    final res = await http
        .get(Uri.parse('$_kApiBase/db/users'))
        .timeout(const Duration(seconds: 3));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data is List
          ? List<Map<String, dynamic>>.from(data)
          : _parseList(res.body);
      if (list.isNotEmpty) absorb(list);
    }
  } catch (_) {}

  // Kaynak 2 — SharedPreferences (yedek)
  final prefs = await SharedPreferences.getInstance();
  absorb(_parseList(prefs.getString(_kUsersDb) ?? ''));

  // Kaynak 3 — localStorage (tarayıcı yedek)
  if (kIsWeb) {
    absorb(_parseList(html.window.localStorage[_kLsUsersDb] ?? ''));
  }

  return combined.values.toList();
}

/// Kullanıcı listesini tüm katmanlara yazar.
/// Veritabanı (API) birincil hedef; yerel depolama yedek.
Future<void> _saveUsers(List<_UserRecord> users) async {
  final encoded = jsonEncode(users);

  // 1. API sunucusu (veritabanı) — PUT ile tüm listeyi yaz
  try {
    final res = await http
        .put(
          Uri.parse('$_kApiBase/db/users'),
          headers: {'Content-Type': 'application/json'},
          body: encoded,
        )
        .timeout(const Duration(seconds: 3));
    if (res.statusCode != 200) {
      // PUT başarısızsa tek tek POST dene
      for (final u in users) {
        try {
          await http
              .post(
                Uri.parse('$_kApiBase/db/users'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(u),
              )
              .timeout(const Duration(seconds: 2));
        } catch (_) {}
      }
    }
  } catch (_) {
    // API erişilemezse tek tek POST dene
    for (final u in users) {
      try {
        await http
            .post(
              Uri.parse('$_kApiBase/db/users'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(u),
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  // 2. SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kUsersDb, encoded);

  // 3. localStorage (web)
  if (kIsWeb) html.window.localStorage[_kLsUsersDb] = encoded;
}

/// Finds a user by lower-cased email. Returns null if not found.
/// E-posta karşılaştırması büyük/küçük harf duyarsızdır.
Future<_UserRecord?> _findUser(String email) async {
  final users = await _loadUsers();
  final key = email.trim().toLowerCase();
  if (key.isEmpty) return null;
  try {
    return users.firstWhere((u) =>
        (u['email'] as String?)?.trim().toLowerCase() == key);
  } catch (_) {
    return null;
  }
}

/// Finds a user by username (displayName, case-insensitive). Returns null if not found.
Future<_UserRecord?> _findUserByUsername(String username) async {
  final users = await _loadUsers();
  final key = username.trim().toLowerCase();
  try {
    return users.firstWhere(
      (u) => (u['name'] as String? ?? '').toLowerCase() == key,
    );
  } catch (_) {
    return null;
  }
}

// ─── Migration: old individual keys → new users_db ───────────────────────────
// Run once on startup so existing accounts survive the schema change.

Future<void> _migrateOldKeys() async {
  final prefs = await SharedPreferences.getInstance();
  // Herhangi bir kaynakta veri varsa migration'ı atla
  final lsHas = kIsWeb
      ? (html.window.localStorage[_kLsUsersDb] ?? '').isNotEmpty
      : false;
  final spHas = prefs.containsKey(_kUsersDb);
  bool apiHas = false;
  try {
    final res = await http
        .get(Uri.parse('$_kApiBase/db/users'))
        .timeout(const Duration(seconds: 2));
    final data = res.statusCode == 200 ? jsonDecode(res.body) : null;
    apiHas = data is List && data.isNotEmpty;
  } catch (_) {}

  if (spHas || lsHas || apiHas) return;

  final allKeys = prefs.getKeys();
  final emailKeys = allKeys.where((k) => k.startsWith('reg_') && !k.startsWith('reg_name_') && !k.startsWith('reg_phone_'));

  final migrated = <_UserRecord>[];
  for (final key in emailKeys) {
    final rawEmail = key.replaceFirst('reg_', '');
    final email = rawEmail.trim().toLowerCase();
    final password = prefs.getString(key) ?? '';
    final name = prefs.getString('reg_name_$rawEmail') ??
        prefs.getString('reg_name_${email}') ?? email.split('@').first;
    final phone = prefs.getString('reg_phone_$rawEmail') ??
        prefs.getString('reg_phone_$email');
    migrated.add({
      'email': email,
      'password': password,
      'name': name,
      if (phone != null) 'phone': phone,
      'uid': 'demo_${email.hashCode.abs()}',
    });
  }

  // Write to new format (even if empty, so migration never runs again)
  await _saveUsers(migrated);
}

// ─── Auth state ───────────────────────────────────────────────────────────────

final _demoUserNotifier = StateProvider<DemoUser?>((ref) => null);

final authStateProvider = StreamProvider<DemoUser?>((ref) {
  return Stream.fromFuture(_restoreSession(ref));
});

Future<DemoUser?> _restoreSession(Ref ref) async {
  await _migrateOldKeys();
  final prefs = await SharedPreferences.getInstance();

  // Önce SharedPreferences, sonra web'de localStorage (oturum kalıcılığı)
  String? uid = prefs.getString('demo_uid');
  String? name = prefs.getString('demo_name');
  String? email = prefs.getString('demo_email');
  String? phone = prefs.getString('demo_phone');
  String? countryCode = prefs.getString('demo_country_code');

  if (uid == null && kIsWeb) {
    try {
      final ls = html.window.localStorage[_kLsSession];
      if (ls != null && ls.isNotEmpty) {
        final m = jsonDecode(ls) as Map<String, dynamic>;
        uid = m['uid'] as String?;
        name = m['name'] as String?;
        email = m['email'] as String?;
        phone = m['phone'] as String?;
        countryCode = m['countryCode'] as String?;
        if (uid != null) {
          await prefs.setString('demo_uid', uid);
          if (name != null) await prefs.setString('demo_name', name);
          if (email != null) await prefs.setString('demo_email', email);
          if (phone != null) await prefs.setString('demo_phone', phone);
          if (countryCode != null) await prefs.setString('demo_country_code', countryCode);
        }
      }
    } catch (_) {}
  }

  if (uid == null) return null;
  final user = DemoUser(
    uid: uid,
    displayName: name ?? 'Kullanıcı',
    email: email ?? '',
    phone: phone,
    countryCode: countryCode,
  );
  ref.read(_demoUserNotifier.notifier).state = user;
  return user;
}

final currentUserProvider = Provider<DemoUser?>((ref) {
  return ref.watch(_demoUserNotifier);
});

// ─── Device ID ────────────────────────────────────────────────────────────────

final deviceIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('device_id');
  if (id != null) return id;
  id = 'device_${DateTime.now().millisecondsSinceEpoch}';
  await prefs.setString('device_id', id);
  return id;
});

// ─── Auth Notifier ────────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  // ── Social sign-in (demo only) ──────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => _createDemoSession('Google Kullanıcısı', 'demo@google.com'));
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => _createDemoSession('Apple Kullanıcısı', 'demo@apple.com'));
  }

  // ── Email sign-in ───────────────────────────────────────────────────────────

  /// Sign in with email OR username + password.
  Future<void> signInWithEmail(String emailOrUsername, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final input = emailOrUsername.trim();
      if (input.isEmpty) {
        throw Exception('E-posta veya kullanıcı adı boş bırakılamaz.');
      }
      if (password.length < 6) {
        throw Exception('Şifre en az 6 karakter olmalıdır.');
      }

      // Determine lookup strategy: email vs username
      _UserRecord? user;
      if (input.contains('@')) {
        user = await _findUser(input.toLowerCase());
      } else {
        // Try as username first, then as email prefix fallback
        user = await _findUserByUsername(input) ??
            await _findUser(input.toLowerCase());
      }

      if (user == null) {
        throw Exception('Bu e-posta veya kullanıcı adı kayıtlı değil.');
      }
      if (user['password'] != password) {
        throw Exception('Şifre hatalı. Lütfen tekrar deneyiniz.');
      }

      await _createDemoSession(
        user['name'] as String? ?? input.split('@').first,
        user['email'] as String? ?? input,
        phone: user['phone'] as String?,
        countryCode: user['countryCode'] as String?,
      );
    });
  }

  // ── Email sign-up ───────────────────────────────────────────────────────────

  Future<void> signUpWithEmail(
    String email,
    String password, {
    String name = '',
    String? phone,
    String? countryCode,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final key = email.trim().toLowerCase();
      _validate(key, password);

      final existing = await _findUser(key);
      if (existing != null) {
        throw Exception('Bu kayıt mevcut. Lütfen giriş yapınız.');
      }

      final displayName =
          name.trim().isNotEmpty ? name.trim() : key.split('@').first;

      final users = await _loadUsers();
      users.add({
        'email': key,
        'password': password,
        'name': displayName,
        'uid': 'demo_${key.hashCode.abs()}',
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (countryCode != null && countryCode.isNotEmpty)
          'countryCode': countryCode,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await _saveUsers(users);

      // Save last email for auto-fill (without logging in)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastEmail, key);
    });
  }

  // ── Password reset ──────────────────────────────────────────────────────────

  /// Checks if email is registered; returns display name or null.
  Future<String?> findRegisteredEmail(String email) async {
    final user = await _findUser(email);
    return user == null ? null : (user['name'] as String?) ?? email.split('@').first;
  }

  /// Overwrites the stored password for a registered email.
  Future<void> resetPasswordWithNew(String email, String newPassword) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final key = email.trim().toLowerCase();
      if (newPassword.length < 6) {
        throw Exception('Şifre en az 6 karakter olmalıdır.');
      }
      final users = await _loadUsers();
      final idx = users.indexWhere((u) => u['email'] == key);
      if (idx == -1) throw Exception('Bu e-posta kayıtlı değil.');
      users[idx]['password'] = newPassword;
      await _saveUsers(users);

      // API ile de güncelle
      try {
        await http.put(
          Uri.parse('$_kApiBase/users/${Uri.encodeComponent(key)}/password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'password': newPassword}),
        ).timeout(const Duration(seconds: 2));
      } catch (_) {}
    });
  }

  // ── Auto-fill ───────────────────────────────────────────────────────────────

  /// Returns the last signed-in / registered email for auto-fill.
  static Future<String?> getLastEmail() async {
    // Try direct localStorage first (more persistent)
    final ls = html.window.localStorage['todo_app_last_email'];
    if (ls != null && ls.isNotEmpty) return ls;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastEmail);
  }

  // ── Sign out ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('demo_uid');
    await prefs.remove('demo_name');
    await prefs.remove('demo_email');
    await prefs.remove('demo_phone');
    await prefs.remove('demo_country_code');
    if (kIsWeb) html.window.localStorage.remove(_kLsSession);
    ref.read(_demoUserNotifier.notifier).state = null;
    ref.invalidate(authStateProvider);
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  static void _validate(String emailOrUser, String password) {
    if (emailOrUser.isEmpty) {
      throw Exception('E-posta veya kullanıcı adı boş bırakılamaz.');
    }
    // For sign-up validate email format
    if (emailOrUser.contains('@') && !RegExp(r'.+@.+\..+').hasMatch(emailOrUser)) {
      throw Exception('Geçerli bir e-posta adresi giriniz.');
    }
    if (password.length < 6) {
      throw Exception('Şifre en az 6 karakter olmalıdır.');
    }
  }

  Future<void> _createDemoSession(
    String name,
    String email, {
    String? phone,
    String? countryCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final emailNorm = email.trim().toLowerCase();
    final uid = 'demo_${emailNorm.hashCode.abs()}';
    await prefs.setString('demo_uid', uid);
    await prefs.setString('demo_name', name);
    await prefs.setString('demo_email', emailNorm);
    if (phone != null) await prefs.setString('demo_phone', phone);
    if (countryCode != null) {
      await prefs.setString('demo_country_code', countryCode);
    }
    await prefs.setString(_kLastEmail, emailNorm);
    if (kIsWeb) {
      html.window.localStorage['todo_app_last_email'] = emailNorm;
      // Oturum kalıcılığı — web'de localStorage'a da kaydet (otomatik giriş)
      html.window.localStorage[_kLsSession] = jsonEncode({
      'uid': uid,
      'name': name,
      'email': emailNorm,
      if (phone != null) 'phone': phone,
      if (countryCode != null) 'countryCode': countryCode,
    });
    }

    ref.read(_demoUserNotifier.notifier).state = DemoUser(
      uid: uid,
      displayName: name,
      email: email,
      phone: phone,
      countryCode: countryCode,
    );

    await _seedDemoFriendsIfNeeded(
        uid: uid, email: email.trim().toLowerCase());
  }

  static Future<void> _seedDemoFriendsIfNeeded({
    required String uid,
    required String email,
  }) async {
    if (email != 'ismailsariogm@gmail.com') return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('demo_friends_seeded') == true) return;

    final repo = ChatRepository.instance;
    final now = DateTime.now();

    const demoFriends = [
      (uid: 'demo_friend_zeynep', name: 'Zeynep Arslan',  email: 'zeynep.arslan@demo.com',  color: '#CF4DA6'),
      (uid: 'demo_friend_mert',   name: 'Mert Kaya',      email: 'mert.kaya@demo.com',      color: '#3B82F6'),
      (uid: 'demo_friend_elif',   name: 'Elif Demir',     email: 'elif.demir@demo.com',     color: '#10B981'),
    ];

    for (final f in demoFriends) {
      final entity = ChatUserEntity(
        uid: f.uid,
        displayName: f.name,
        email: f.email,
        userCode: generateUserCode(f.uid),
        avatarColorHex: f.color,
        createdAt: now,
      );
      await repo.registerUser(entity);
      await repo.addFriend(uid, entity);
    }

    await prefs.setBool('demo_friends_seeded', true);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
