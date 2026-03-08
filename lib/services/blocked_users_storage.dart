import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Engellenen kullanıcılar depolama.
/// blockerId -> blockedId ilişkisi: A, B'yi engellediğinde ikisi de birbirini görmez.
const _kBlockedByMe = 'blocked_by_me_';
const _kBlockedMe = 'blocked_me_';

class BlockedUsersStorage {
  BlockedUsersStorage._();
  static final BlockedUsersStorage instance = BlockedUsersStorage._();

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  /// [blockerId] tarafından engellenen kullanıcı ID'leri
  Future<List<String>> getBlockedByMe(String blockerId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_kBlockedByMe$blockerId');
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  /// [userId]'yi engelleyen kullanıcı ID'leri (beni engelleyenler)
  Future<List<String>> getBlockedMe(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_kBlockedMe$userId');
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  /// [userId] ile görüşmemesi gereken tüm kullanıcı ID'leri
  /// (benim engellediklerim + beni engelleyenler)
  Future<Set<String>> getInvisibleUserIds(String userId) async {
    final byMe = await getBlockedByMe(userId);
    final me = await getBlockedMe(userId);
    return {...byMe, ...me};
  }

  /// [blockerId], [blockedId]'yi engeller. İki kullanıcı artık birbirini görmez.
  Future<void> blockUser(String blockerId, String blockedId) async {
    if (blockerId == blockedId) return;

    final prefs = await _prefs;

    final byMe = await getBlockedByMe(blockerId);
    if (byMe.contains(blockedId)) return;
    byMe.add(blockedId);
    await prefs.setString(
        '$_kBlockedByMe$blockerId', jsonEncode(byMe));

    final me = await getBlockedMe(blockedId);
    if (!me.contains(blockerId)) {
      me.add(blockerId);
      await prefs.setString(
          '$_kBlockedMe$blockedId', jsonEncode(me));
    }
  }

  /// [blockerId], [blockedId] engelini kaldırır.
  Future<void> unblockUser(String blockerId, String blockedId) async {
    final prefs = await _prefs;

    final byMe = await getBlockedByMe(blockerId);
    byMe.remove(blockedId);
    await prefs.setString(
        '$_kBlockedByMe$blockerId', jsonEncode(byMe));

    final me = await getBlockedMe(blockedId);
    me.remove(blockerId);
    await prefs.setString(
        '$_kBlockedMe$blockedId', jsonEncode(me));
  }

  /// [blockerId]'nin engellediği kullanıcı ID'leri (engellenenler listesi)
  Future<List<String>> getBlockedUserIds(String blockerId) async {
    return getBlockedByMe(blockerId);
  }
}
