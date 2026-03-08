import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/chat_repository.dart';
import '../../domain/entities/chat_user_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../auth/auth_provider.dart';
import '../settings/blocked_users_provider.dart' show blockedUsersStorageProvider, myInvisibleUserIdsProvider, blockedUsersListProvider, blockedUserIdsProvider;

// ─── Repository ───────────────────────────────────────────────────────────────

final chatRepositoryProvider = Provider<ChatRepository>((_) {
  return ChatRepository.instance;
});

// ─── Current user chat profile ────────────────────────────────────────────────

final chatUserProfileProvider = FutureProvider<ChatUserEntity?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final prefs = await SharedPreferences.getInstance();
  final codeKey = 'chat_code_${user.uid}';
  String code = prefs.getString(codeKey) ?? '';
  if (code.isEmpty) {
    code = generateUserCode(user.uid);
    await prefs.setString(codeKey, code);
  }

  final profile = ChatUserEntity(
    uid: user.uid,
    displayName: user.displayName,
    email: user.email,
    userCode: code,
    avatarColorHex: pickAvatarColor(user.uid),
    createdAt: DateTime.now(),
  );

  await ref.read(chatRepositoryProvider).registerUser(profile);
  return profile;
});

// ─── Friends stream ───────────────────────────────────────────────────────────

final friendsStreamProvider = StreamProvider<List<ChatUserEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(chatRepositoryProvider).watchFriends(user.uid);
});

/// Engellenen kullanıcılar filtrelenmiş arkadaş listesi
final filteredFriendsProvider = Provider<AsyncValue<List<ChatUserEntity>>>((ref) {
  final friendsAsync = ref.watch(friendsStreamProvider);
  final invisibleAsync = ref.watch(myInvisibleUserIdsProvider);

  if (friendsAsync.isLoading) return const AsyncValue.loading();
  if (friendsAsync.hasError) return AsyncValue.error(friendsAsync.error!, friendsAsync.stackTrace!);

  final friends = friendsAsync.value!;
  if (invisibleAsync.isLoading) return AsyncValue.data(friends);
  if (invisibleAsync.hasError) return AsyncValue.data(friends);

  final invisible = invisibleAsync.value!;
  return AsyncValue.data(friends.where((f) => !invisible.contains(f.uid)).toList());
});

// ─── Conversations stream ─────────────────────────────────────────────────────

final conversationsStreamProvider =
    StreamProvider<List<ConversationEntity>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(chatRepositoryProvider).watchConversations(user.uid);
});

/// Engellenen kullanıcılarla olan direkt sohbetler filtrelenmiş
final filteredConversationsProvider =
    Provider<AsyncValue<List<ConversationEntity>>>((ref) {
  final convsAsync = ref.watch(conversationsStreamProvider);
  final invisibleAsync = ref.watch(myInvisibleUserIdsProvider);
  final user = ref.watch(currentUserProvider);

  if (convsAsync.isLoading) return const AsyncValue.loading();
  if (convsAsync.hasError) return AsyncValue.error(convsAsync.error!, convsAsync.stackTrace!);

  final convs = convsAsync.value!;
  if (user == null) return AsyncValue.data(convs);
  if (invisibleAsync.isLoading) return AsyncValue.data(convs);
  if (invisibleAsync.hasError) return AsyncValue.data(convs);

  final invisible = invisibleAsync.value!;
  final filtered = convs.where((c) {
    if (c.type != ConversationType.direct) return true;
    final others = c.participants.where((p) => p.uid != user.uid);
    if (others.isEmpty) return true;
    return !invisible.contains(others.first.uid);
  }).toList();
  return AsyncValue.data(filtered);
});

// ─── Messages stream (per conversation) ──────────────────────────────────────

final messagesStreamProvider =
    StreamProvider.family<List<MessageEntity>, String>((ref, convId) {
  return ref.read(chatRepositoryProvider).watchMessages(convId);
});

// ─── Active conversation ──────────────────────────────────────────────────────

final activeConversationProvider =
    StateProvider<ConversationEntity?>((ref) => null);

// ─── Chat panel open/close ────────────────────────────────────────────────────

final chatPanelOpenProvider = StateProvider<bool>((ref) => false);

// ─── Actions ─────────────────────────────────────────────────────────────────

class ChatActions {
  ChatActions(this._ref);
  final Ref _ref;

  ChatRepository get _repo => _ref.read(chatRepositoryProvider);

  /// Koda göre kullanıcı arar ve arkadaş olarak ekler.
  /// Başarı → null, hata → hata mesajı döner.
  Future<String?> addFriendByCode(String code) async {
    final user = _ref.read(currentUserProvider);
    final profile = await _ref.read(chatUserProfileProvider.future);
    if (user == null || profile == null) return 'Oturum açılmamış';

    final found = await _repo.findUserByCode(code);
    if (found == null) return 'Bu kodla kullanıcı bulunamadı';
    if (found.uid == user.uid) return 'Kendinizi ekleyemezsiniz';

    await _repo.addFriend(user.uid, found);
    return null;
  }

  /// Arkadaş ile direkt sohbet başlatır ve aktif konuşma olarak ayarlar.
  Future<ConversationEntity?> openDirectChat(ChatUserEntity friend) async {
    final profile = await _ref.read(chatUserProfileProvider.future);
    if (profile == null) return null;

    final conv = await _repo.createDirectConversation(
      me: profile,
      friend: friend,
    );
    _ref.read(activeConversationProvider.notifier).state = conv;
    return conv;
  }

  /// Grup sohbeti oluşturur.
  Future<ConversationEntity?> createGroup({
    required String groupName,
    required List<ChatUserEntity> members,
  }) async {
    final profile = await _ref.read(chatUserProfileProvider.future);
    if (profile == null) return null;

    final conv = await _repo.createGroupConversation(
      me: profile,
      groupName: groupName,
      members: members,
    );
    _ref.read(activeConversationProvider.notifier).state = conv;
    return conv;
  }

  /// Mesaj gönderir.
  Future<void> sendMessage({
    required ConversationEntity conversation,
    required String content,
  }) async {
    if (content.trim().isEmpty) return;
    final profile = await _ref.read(chatUserProfileProvider.future);
    if (profile == null) return;

    await _repo.sendMessage(
      conversationId: conversation.id,
      senderId: profile.uid,
      senderName: profile.displayName,
      content: content.trim(),
      ownerUid: profile.uid,
      participantUids: conversation.participants.map((p) => p.uid).toList(),
    );
  }

  /// Konuşmayı siler.
  Future<void> deleteConversation(String convId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    await _repo.deleteConversation(user.uid, convId);

    final active = _ref.read(activeConversationProvider);
    if (active?.id == convId) {
      _ref.read(activeConversationProvider.notifier).state = null;
    }
  }

  /// Arkadaşı kaldırır.
  Future<void> removeFriend(String friendUid) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    await _repo.removeFriend(user.uid, friendUid);
  }

  /// Arkadaşı engeller (arkadaşlıktan çıkarır ve engeller).
  Future<void> blockFriend(String friendUid) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    await _repo.removeFriend(user.uid, friendUid);
    await _ref.read(blockedUsersStorageProvider).blockUser(user.uid, friendUid);
    _ref.invalidate(myInvisibleUserIdsProvider);
    _ref.invalidate(blockedUsersListProvider);
    _ref.invalidate(blockedUserIdsProvider(user.uid));
  }
}

final chatActionsProvider = Provider<ChatActions>((ref) => ChatActions(ref));
