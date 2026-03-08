import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/chat_user_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../services/db_client.dart';

// ─── Key constants ────────────────────────────────────────────────────────────
const _uuid = Uuid();

String _convKey(String uid) => 'chat_conversations_$uid';
String _msgKey(String convId) => 'chat_messages_$convId';
String _friendsKey(String uid) => 'chat_friends_$uid';
const _registryKey = 'chat_user_registry';

/// Tüm sohbet verilerini yöneten repository.
/// SharedPreferences + StreamController ile reaktif veri akışı sağlar.
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  // ─── Stream controllers ────────────────────────────────────────────────────

  final _convControllers = <String, StreamController<List<ConversationEntity>>>{};
  final _msgControllers = <String, StreamController<List<MessageEntity>>>{};
  final _friendControllers = <String, StreamController<List<ChatUserEntity>>>{};

  // ─── User Registry ────────────────────────────────────────────────────────

  /// Global kullanıcı dizinine kullanıcıyı kaydeder / günceller.
  Future<void> registerUser(ChatUserEntity user) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await _loadRegistry(prefs);
    final idx = users.indexWhere((u) => u.uid == user.uid);
    if (idx >= 0) {
      users[idx] = user;
    } else {
      users.add(user);
    }
    await prefs.setString(_registryKey, ChatUserEntity.toJsonList(users));
    // DB sunucusuna da kaydet
    await DbClient.upsertItem('user_registry', user.toJson());
  }

  /// Kod ile kullanıcı bulur (ör. "#AB3X7K").
  Future<ChatUserEntity?> findUserByCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final users = await _loadRegistry(prefs);
    final normalized = code.trim().toUpperCase();
    try {
      return users.firstWhere(
        (u) => u.userCode.toUpperCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<ChatUserEntity>> _loadRegistry(SharedPreferences prefs) async {
    // DB sunucusundan yükle
    final serverItems = await DbClient.getList('user_registry');
    // SharedPreferences'dan yükle
    List<ChatUserEntity> localUsers = [];
    final raw = prefs.getString(_registryKey);
    if (raw != null) {
      try { localUsers = ChatUserEntity.fromJsonList(raw); } catch (_) {}
    }
    // Birleştir
    final merged = DbClient.merge(
      serverItems,
      localUsers.map((u) => u.toJson()).toList(),
    );
    if (merged.isNotEmpty) {
      await prefs.setString(_registryKey, ChatUserEntity.toJsonList(
        merged.map(ChatUserEntity.fromJson).toList(),
      ));
    }
    return merged.map(ChatUserEntity.fromJson).toList();
  }

  // ─── Friends ──────────────────────────────────────────────────────────────

  Stream<List<ChatUserEntity>> watchFriends(String uid) {
    _friendControllers.putIfAbsent(
      uid,
      () => StreamController<List<ChatUserEntity>>.broadcast(),
    );
    _emitFriends(uid);
    return _friendControllers[uid]!.stream;
  }

  Future<List<ChatUserEntity>> getFriends(String uid) async {
    // Önce DB sunucusundan dene
    final serverItems = await DbClient.getMap('friends', uid);
    if (serverItems.isNotEmpty) {
      return serverItems.map(ChatUserEntity.fromJson).toList();
    }
    // Fallback: SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_friendsKey(uid));
    if (raw == null) return [];
    return ChatUserEntity.fromJsonList(raw);
  }

  Future<void> addFriend(String myUid, ChatUserEntity friend) async {
    final prefs = await SharedPreferences.getInstance();
    final friends = await getFriends(myUid);
    if (friends.any((f) => f.uid == friend.uid)) return;
    friends.add(friend);
    await prefs.setString(_friendsKey(myUid), ChatUserEntity.toJsonList(friends));
    await DbClient.putMap('friends', myUid,
        friends.map((f) => f.toJson()).toList());
    await _emitFriends(myUid);
  }

  Future<void> removeFriend(String myUid, String friendUid) async {
    final prefs = await SharedPreferences.getInstance();
    final friends = await getFriends(myUid);
    friends.removeWhere((f) => f.uid == friendUid);
    await prefs.setString(_friendsKey(myUid), ChatUserEntity.toJsonList(friends));
    await DbClient.putMap('friends', myUid,
        friends.map((f) => f.toJson()).toList());
    await _emitFriends(myUid);
  }

  Future<void> _emitFriends(String uid) async {
    final friends = await getFriends(uid);
    _friendControllers[uid]?.add(friends);
  }

  // ─── Conversations ────────────────────────────────────────────────────────

  Stream<List<ConversationEntity>> watchConversations(String uid) {
    _convControllers.putIfAbsent(
      uid,
      () => StreamController<List<ConversationEntity>>.broadcast(),
    );
    _emitConversations(uid);
    return _convControllers[uid]!.stream;
  }

  Future<List<ConversationEntity>> getConversations(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_convKey(uid));
    if (raw == null) return [];
    return ConversationEntity.fromJsonList(raw);
  }

  /// Direkt sohbet oluşturur (zaten varsa mevcut olanı döndürür).
  Future<ConversationEntity> createDirectConversation({
    required ChatUserEntity me,
    required ChatUserEntity friend,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Deterministik ID — her iki tarafta da aynı ID oluşsun
    final ids = [me.uid, friend.uid]..sort();
    final convId = 'direct_${ids[0]}_${ids[1]}';

    // Benim tarafım
    final myConvs = await getConversations(me.uid);
    if (!myConvs.any((c) => c.id == convId)) {
      final conv = ConversationEntity(
        id: convId,
        type: ConversationType.direct,
        participants: [me, friend],
        ownerUid: me.uid,
        createdAt: DateTime.now(),
      );
      myConvs.insert(0, conv);
      await prefs.setString(_convKey(me.uid), ConversationEntity.toJsonList(myConvs));
      await _emitConversations(me.uid);
      return conv;
    }
    return myConvs.firstWhere((c) => c.id == convId);
  }

  /// Grup sohbeti oluşturur.
  Future<ConversationEntity> createGroupConversation({
    required ChatUserEntity me,
    required String groupName,
    required List<ChatUserEntity> members,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final convId = 'group_${_uuid.v4()}';
    final allParticipants = [me, ...members];

    final conv = ConversationEntity(
      id: convId,
      type: ConversationType.group,
      participants: allParticipants,
      ownerUid: me.uid,
      groupName: groupName,
      groupAvatarColorHex: kAvatarColors[Random().nextInt(kAvatarColors.length)],
      createdAt: DateTime.now(),
    );

    final convs = await getConversations(me.uid);
    convs.insert(0, conv);
    await prefs.setString(_convKey(me.uid), ConversationEntity.toJsonList(convs));
    await _emitConversations(me.uid);
    return conv;
  }

  Future<void> _updateConversationMeta({
    required String uid,
    required String convId,
    required String lastMessage,
    required String lastSenderName,
    required DateTime lastMessageAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final convs = await getConversations(uid);
    final idx = convs.indexWhere((c) => c.id == convId);
    if (idx < 0) return;
    final updated = convs[idx].copyWith(
      lastMessage: lastMessage,
      lastSenderName: lastSenderName,
      lastMessageAt: lastMessageAt,
    );
    convs.removeAt(idx);
    convs.insert(0, updated); // en üste taşı
    await prefs.setString(_convKey(uid), ConversationEntity.toJsonList(convs));
    await _emitConversations(uid);
  }

  Future<void> deleteConversation(String uid, String convId) async {
    final prefs = await SharedPreferences.getInstance();
    final convs = await getConversations(uid);
    convs.removeWhere((c) => c.id == convId);
    await prefs.setString(_convKey(uid), ConversationEntity.toJsonList(convs));
    await prefs.remove(_msgKey(convId));
    await _emitConversations(uid);
  }

  Future<void> _emitConversations(String uid) async {
    final convs = await getConversations(uid);
    _convControllers[uid]?.add(convs);
  }

  // ─── Messages ─────────────────────────────────────────────────────────────

  Stream<List<MessageEntity>> watchMessages(String conversationId) {
    _msgControllers.putIfAbsent(
      conversationId,
      () => StreamController<List<MessageEntity>>.broadcast(),
    );
    _emitMessages(conversationId);
    return _msgControllers[conversationId]!.stream;
  }

  Future<List<MessageEntity>> getMessages(String conversationId) async {
    // DB sunucusundan dene
    final serverItems = await DbClient.getMap('messages', conversationId);
    if (serverItems.isNotEmpty) {
      return serverItems.map(MessageEntity.fromJson).toList();
    }
    // Fallback: SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_msgKey(conversationId));
    if (raw == null) return [];
    return MessageEntity.fromJsonList(raw);
  }

  /// Grup ayarları değişikliği bildirimi (sohbette silinemez mesaj)
  static const systemSettingsSenderId = '__system_settings__';

  /// Grup ayarları değişikliğini sohbette bildirir. Mesaj silinemez.
  Future<void> sendGroupSettingsChange({
    required String groupId,
    required String userName,
    required String userRole,
    required String changeDescription,
    required String ownerUid,
    required List<String> participantUids,
  }) async {
    final roleLabel = _roleLabel(userRole);
    final content = '$changeDescription - $userName ($roleLabel)';
    await sendMessage(
      conversationId: 'group_proj_$groupId',
      senderId: systemSettingsSenderId,
      senderName: 'Grup Ayarları',
      content: content,
      ownerUid: ownerUid,
      participantUids: participantUids,
    );
  }

  static String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'yonetici':
      case 'owner':
        return 'Yönetici';
      case 'kıdemli':
        return 'Kıdemli';
      case 'uye':
      case 'member':
        return 'Üye';
      default:
        return role;
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String content,
    required String ownerUid,
    required List<String> participantUids,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final msg = MessageEntity(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      sentAt: DateTime.now(),
    );

    final msgs = await getMessages(conversationId);
    msgs.add(msg);
    await prefs.setString(_msgKey(conversationId), MessageEntity.toJsonList(msgs));
    // DB sunucusuna yaz
    await DbClient.putMap('messages', conversationId,
        msgs.map((m) => m.toJson()).toList());
    _msgControllers[conversationId]?.add(msgs);

    // Konuşma meta verisini güncelle (mesajı gönderen için)
    await _updateConversationMeta(
      uid: ownerUid,
      convId: conversationId,
      lastMessage: content,
      lastSenderName: senderName,
      lastMessageAt: msg.sentAt,
    );
  }

  Future<void> _emitMessages(String conversationId) async {
    final msgs = await getMessages(conversationId);
    _msgControllers[conversationId]?.add(msgs);
  }

  Future<void> editMessage(
    String conversationId,
    String messageId,
    String newContent,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final msgs = await getMessages(conversationId);
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    msgs[idx] = msgs[idx].copyWith(content: newContent, editedAt: DateTime.now());
    await prefs.setString(_msgKey(conversationId), MessageEntity.toJsonList(msgs));
    await DbClient.putMap('messages', conversationId, msgs.map((m) => m.toJson()).toList());
    _msgControllers[conversationId]?.add(msgs);
  }

  Future<void> deleteMessageForMe(
    String conversationId,
    String messageId,
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final msgs = await getMessages(conversationId);
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    final deleted = List<String>.from(msgs[idx].deletedForUserIds)..add(userId);
    msgs[idx] = msgs[idx].copyWith(deletedForUserIds: deleted);
    await prefs.setString(_msgKey(conversationId), MessageEntity.toJsonList(msgs));
    await DbClient.putMap('messages', conversationId, msgs.map((m) => m.toJson()).toList());
    _msgControllers[conversationId]?.add(msgs);
  }

  Future<void> deleteMessageForEveryone(
    String conversationId,
    String messageId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final msgs = await getMessages(conversationId);
    final idx = msgs.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;
    msgs[idx] = msgs[idx].copyWith(isDeleted: true);
    await prefs.setString(_msgKey(conversationId), MessageEntity.toJsonList(msgs));
    await DbClient.putMap('messages', conversationId, msgs.map((m) => m.toJson()).toList());
    _msgControllers[conversationId]?.add(msgs);
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  void dispose() {
    for (final ctrl in _convControllers.values) {
      ctrl.close();
    }
    for (final ctrl in _msgControllers.values) {
      ctrl.close();
    }
    for (final ctrl in _friendControllers.values) {
      ctrl.close();
    }
    _convControllers.clear();
    _msgControllers.clear();
    _friendControllers.clear();
  }
}
