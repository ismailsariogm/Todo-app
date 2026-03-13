/// Kişisel görevleri kategorize etmek için dosya (klasör) entity.
/// Örn: Market Alışverişi, Gelir Giderler, Akaryakıt, Günlük Rutin
class TaskFileEntity {
  const TaskFileEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    this.colorHex = '#6366F1',
    this.sortOrder = 0,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String colorHex;
  final int sortOrder;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'colorHex': colorHex,
        'sortOrder': sortOrder,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskFileEntity.fromJson(Map<String, dynamic> m) => TaskFileEntity(
        id: m['id'] as String,
        ownerId: m['ownerId'] as String,
        name: m['name'] as String,
        colorHex: (m['colorHex'] as String?) ?? '#6366F1',
        sortOrder: (m['sortOrder'] as int?) ?? 0,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}
