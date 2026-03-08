class ProjectEntity {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final bool isShared;
  final String colorHex;
  final String? photoBase64; // grup fotoğrafı (base64)
  final DateTime createdAt;
  final DateTime updatedAt;
  /// Topluluk grubu ise true (10 alt grup içerebilir)
  final bool isCommunityGroup;
  /// Alt grup ise parent topluluk grubunun id'si
  final String? parentCommunityId;

  const ProjectEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.isShared = false,
    this.colorHex = '#6366F1',
    this.photoBase64,
    required this.createdAt,
    required this.updatedAt,
    this.isCommunityGroup = false,
    this.parentCommunityId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'name': name,
    'description': description,
    'isShared': isShared,
    'colorHex': colorHex,
    'photoBase64': photoBase64,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isCommunityGroup': isCommunityGroup,
    'parentCommunityId': parentCommunityId,
  };

  factory ProjectEntity.fromJson(Map<String, dynamic> m) => ProjectEntity(
    id: m['id'] as String,
    ownerId: m['ownerId'] as String,
    name: m['name'] as String,
    description: m['description'] as String?,
    isShared: (m['isShared'] as bool?) ?? false,
    colorHex: (m['colorHex'] as String?) ?? '#6366F1',
    photoBase64: m['photoBase64'] as String?,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: DateTime.parse(m['updatedAt'] as String),
    isCommunityGroup: (m['isCommunityGroup'] as bool?) ?? false,
    parentCommunityId: m['parentCommunityId'] as String?,
  );
}

class GroupMemberEntity {
  final String groupId;
  final String userId;
  final String email;
  final String displayName;
  final String role;
  final DateTime joinedAt;

  const GroupMemberEntity({
    required this.groupId,
    required this.userId,
    required this.email,
    required this.displayName,
    this.role = 'member',
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'userId': userId,
    'email': email,
    'displayName': displayName,
    'role': role,
    'joinedAt': joinedAt.toIso8601String(),
  };

  factory GroupMemberEntity.fromJson(Map<String, dynamic> m) =>
      GroupMemberEntity(
        groupId: m['groupId'] as String,
        userId: m['userId'] as String,
        email: m['email'] as String,
        displayName: m['displayName'] as String,
        role: (m['role'] as String?) ?? 'member',
        joinedAt: DateTime.parse(m['joinedAt'] as String),
      );
}
