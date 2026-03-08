import 'dart:convert';
import 'chat_user_entity.dart';

enum ConversationType { direct, group }

/// Bir sohbet oturumu (1-1 veya grup).
class ConversationEntity {
  const ConversationEntity({
    required this.id,
    required this.type,
    required this.participants,
    required this.ownerUid,
    this.groupName,
    this.groupAvatarColorHex = '#8B40F0',
    this.lastMessage,
    this.lastSenderName,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
  });

  final String id;
  final ConversationType type;
  final List<ChatUserEntity> participants; // tüm katılımcılar (kendim dahil)
  final String ownerUid; // bu konuşmanın sahibi (mevcut kullanıcı)
  final String? groupName;
  final String groupAvatarColorHex;
  final String? lastMessage;
  final String? lastSenderName;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;

  /// Direkt sohbette karşı tarafı döndürür
  ChatUserEntity? get otherParticipant => type == ConversationType.direct
      ? participants.firstWhere(
          (p) => p.uid != ownerUid,
          orElse: () => participants.first,
        )
      : null;

  /// Görüntülenecek ad
  String get displayName {
    if (type == ConversationType.group) return groupName ?? 'Grup';
    return otherParticipant?.displayName ?? 'Bilinmeyen';
  }

  /// Görüntülenecek avatar rengi
  String get avatarColor {
    if (type == ConversationType.group) return groupAvatarColorHex;
    return otherParticipant?.avatarColorHex ?? '#8B40F0';
  }

  /// Avatar baş harfleri
  String get avatarInitials {
    if (type == ConversationType.group) {
      return (groupName ?? 'G').isNotEmpty
          ? (groupName ?? 'G')[0].toUpperCase()
          : 'G';
    }
    return otherParticipant?.initials ?? '?';
  }

  factory ConversationEntity.fromJson(Map<String, dynamic> json) {
    return ConversationEntity(
      id: json['id'] as String,
      type: json['type'] == 'group'
          ? ConversationType.group
          : ConversationType.direct,
      participants: (json['participants'] as List)
          .cast<Map<String, dynamic>>()
          .map(ChatUserEntity.fromJson)
          .toList(),
      ownerUid: json['ownerUid'] as String,
      groupName: json['groupName'] as String?,
      groupAvatarColorHex:
          json['groupAvatarColorHex'] as String? ?? '#8B40F0',
      lastMessage: json['lastMessage'] as String?,
      lastSenderName: json['lastSenderName'] as String?,
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'] as String)
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == ConversationType.group ? 'group' : 'direct',
        'participants': participants.map((p) => p.toJson()).toList(),
        'ownerUid': ownerUid,
        'groupName': groupName,
        'groupAvatarColorHex': groupAvatarColorHex,
        'lastMessage': lastMessage,
        'lastSenderName': lastSenderName,
        'lastMessageAt': lastMessageAt?.toIso8601String(),
        'unreadCount': unreadCount,
        'createdAt': createdAt.toIso8601String(),
      };

  static String toJsonList(List<ConversationEntity> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<ConversationEntity> fromJsonList(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(ConversationEntity.fromJson)
        .toList();
  }

  ConversationEntity copyWith({
    String? lastMessage,
    String? lastSenderName,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) =>
      ConversationEntity(
        id: id,
        type: type,
        participants: participants,
        ownerUid: ownerUid,
        groupName: groupName,
        groupAvatarColorHex: groupAvatarColorHex,
        lastMessage: lastMessage ?? this.lastMessage,
        lastSenderName: lastSenderName ?? this.lastSenderName,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
        createdAt: createdAt,
      );
}
