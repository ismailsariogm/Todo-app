import 'dart:convert';

/// Bir kullanıcının sohbet profili.
/// [userCode] — arkadaş eklemek için paylaşılan benzersiz 6 haneli kod (ör. "AB3X7K").
class ChatUserEntity {
  const ChatUserEntity({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.userCode,
    this.avatarColorHex = '#8B40F0',
    required this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String userCode; // "#AB3X7K" formatında benzersiz ID
  final String avatarColorHex;
  final DateTime createdAt;

  // Görüntülenecek kısa ad
  String get initials {
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  factory ChatUserEntity.fromJson(Map<String, dynamic> json) {
    return ChatUserEntity(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      userCode: json['userCode'] as String,
      avatarColorHex: json['avatarColorHex'] as String? ?? '#8B40F0',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'userCode': userCode,
        'avatarColorHex': avatarColorHex,
        'createdAt': createdAt.toIso8601String(),
      };

  static String toJsonList(List<ChatUserEntity> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<ChatUserEntity> fromJsonList(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(ChatUserEntity.fromJson)
        .toList();
  }

  ChatUserEntity copyWith({String? displayName, String? avatarColorHex}) =>
      ChatUserEntity(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email,
        userCode: userCode,
        avatarColorHex: avatarColorHex ?? this.avatarColorHex,
        createdAt: createdAt,
      );
}

/// Benzersiz kullanıcı kodu üretici.
/// UID'den deterministik 6 karakter alfanümerik kod üretir.
String generateUserCode(String uid) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  var h = uid.codeUnits.fold(0, (acc, c) => acc * 31 + c) & 0x7FFFFFFF;
  final buf = StringBuffer('#');
  for (int i = 0; i < 6; i++) {
    buf.write(chars[h % chars.length]);
    h = (h ~/ chars.length) + (i * 7919); // salt to reduce collisions
  }
  return buf.toString();
}

/// Avatar renkleri — kullanıcıya otomatik atanır
const kAvatarColors = [
  '#8B40F0', '#CF4DA6', '#3B82F6', '#10B981',
  '#F59E0B', '#EF4444', '#6366F1', '#EC4899',
];

String pickAvatarColor(String uid) {
  final idx = uid.hashCode.abs() % kAvatarColors.length;
  return kAvatarColors[idx];
}
