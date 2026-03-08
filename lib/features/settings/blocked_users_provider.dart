import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../../domain/entities/chat_user_entity.dart' show ChatUserEntity, pickAvatarColor;
import '../../services/blocked_users_storage.dart';
import '../chat/chat_provider.dart';

final blockedUsersStorageProvider = Provider<BlockedUsersStorage>((_) {
  return BlockedUsersStorage.instance;
});

/// Engellenen kullanıcı ID'leri (akış)
final blockedUserIdsProvider =
    StreamProvider.family<List<String>, String>((ref, userId) async* {
  final storage = ref.watch(blockedUsersStorageProvider);
  yield await storage.getBlockedByMe(userId);
  // Yenileme için periyodik kontrol
  await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
    yield await storage.getBlockedByMe(userId);
  }
});

/// Mevcut kullanıcının engellediği kullanıcı ID'leri
final myBlockedUserIdsProvider = Provider<List<String>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(blockedUserIdsProvider(user.uid)).valueOrNull ?? [];
});

/// Mevcut kullanıcının görüşmemesi gereken ID'ler (engellediklerim + beni engelleyenler)
final myInvisibleUserIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};
  final storage = ref.watch(blockedUsersStorageProvider);
  return storage.getInvisibleUserIds(user.uid);
});

/// Engellenen kullanıcılar (ChatUserEntity) — user_registry'den bilgi alır
/// Registry'de bulunmayanlar için placeholder entity oluşturulur
final blockedUsersListProvider = FutureProvider<List<ChatUserEntity>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final storage = ref.watch(blockedUsersStorageProvider);
  final blockedIds = await storage.getBlockedByMe(user.uid);
  if (blockedIds.isEmpty) return [];

  final registry = await ref.read(chatRepositoryProvider).getRegistryUsers();
  final registryMap = {for (final u in registry) u.uid: u};

  return blockedIds.map((uid) {
    final found = registryMap[uid];
    if (found != null) return found;
    return ChatUserEntity(
      uid: uid,
      displayName: 'Bilinmeyen kullanıcı',
      email: '',
      userCode: '#${uid.length > 6 ? uid.substring(0, 6) : uid}',
      avatarColorHex: pickAvatarColor(uid),
      createdAt: DateTime.now(),
    );
  }).toList();
});
