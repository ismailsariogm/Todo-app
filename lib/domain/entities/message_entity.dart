import 'dart:convert';

/// Tek bir sohbet mesajı.
class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.sentAt,
    this.isRead = false,
    this.isDeleted = false,
    this.deletedForUserIds = const [],
    this.editedAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime sentAt;
  final bool isRead;
  final bool isDeleted;
  final List<String> deletedForUserIds;
  final DateTime? editedAt;

  factory MessageEntity.fromJson(Map<String, dynamic> json) {
    return MessageEntity(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      content: json['content'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedForUserIds: (json['deletedForUserIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'sentAt': sentAt.toIso8601String(),
        'isRead': isRead,
        'isDeleted': isDeleted,
        'deletedForUserIds': deletedForUserIds,
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      };

  static String toJsonList(List<MessageEntity> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<MessageEntity> fromJsonList(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(MessageEntity.fromJson)
        .toList();
  }

  MessageEntity copyWith({
    bool? isRead,
    bool? isDeleted,
    List<String>? deletedForUserIds,
    String? content,
    DateTime? editedAt,
  }) =>
      MessageEntity(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        content: content ?? this.content,
        sentAt: sentAt,
        isRead: isRead ?? this.isRead,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedForUserIds: deletedForUserIds ?? this.deletedForUserIds,
        editedAt: editedAt ?? this.editedAt,
      );
}
