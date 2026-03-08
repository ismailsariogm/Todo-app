import 'package:flutter_test/flutter_test.dart';
import 'package:todo_note/domain/entities/task_entity.dart';

void main() {
  group('TaskEntity', () {
    late TaskEntity baseTask;

    setUp(() {
      baseTask = TaskEntity(
        id: 'test-id-1',
        ownerId: 'user-1',
        title: 'Test Görevi',
        createdAt: DateTime(2025, 1, 1, 9, 0),
        updatedAt: DateTime(2025, 1, 1, 9, 0),
        deviceId: 'device-1',
      );
    });

    test('isOverdue returns false when dueAt is in the future', () {
      final future = DateTime.now().add(const Duration(days: 1));
      final task = baseTask.copyWith(dueAt: future);
      expect(task.isOverdue, isFalse);
    });

    test('isOverdue returns true when dueAt is in the past and not completed', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      final task = baseTask.copyWith(dueAt: past);
      expect(task.isOverdue, isTrue);
    });

    test('isOverdue returns false for completed tasks even if past due', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      final task = baseTask.copyWith(
        dueAt: past,
        isCompleted: true,
        completedAt: DateTime.now(),
      );
      expect(task.isOverdue, isFalse);
    });

    test('isDueToday returns true when dueAt is today', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 0);
      final task = baseTask.copyWith(dueAt: today);
      expect(task.isDueToday, isTrue);
    });

    test('isDueTomorrow returns true when dueAt is tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final task = baseTask.copyWith(dueAt: tomorrow);
      expect(task.isDueTomorrow, isTrue);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = baseTask.copyWith(title: 'Yeni Başlık');
      expect(updated.id, equals(baseTask.id));
      expect(updated.ownerId, equals(baseTask.ownerId));
      expect(updated.title, equals('Yeni Başlık'));
      expect(updated.priority, equals(baseTask.priority));
    });

    test('copyWith with clearDueAt sets dueAt to null', () {
      final withDate = baseTask.copyWith(
        dueAt: DateTime.now().add(const Duration(days: 1)),
      );
      final cleared = withDate.copyWith(clearDueAt: true);
      expect(cleared.dueAt, isNull);
    });

    test('toFirestore serializes correctly', () {
      final map = baseTask.toFirestore();
      expect(map['id'], equals('test-id-1'));
      expect(map['title'], equals('Test Görevi'));
      expect(map['ownerId'], equals('user-1'));
      expect(map['isCompleted'], isFalse);
      expect(map['isDeleted'], isFalse);
    });

    test('fromFirestore round-trips correctly', () {
      final map = baseTask.toFirestore();
      final restored = TaskEntity.fromFirestore(map);
      expect(restored.id, equals(baseTask.id));
      expect(restored.title, equals(baseTask.title));
      expect(restored.priority, equals(baseTask.priority));
      expect(restored.labels, equals(baseTask.labels));
    });

    test('version increments on copyWith', () {
      final updated = baseTask.copyWith(title: 'Updated');
      expect(updated.version, equals(baseTask.version + 1));
    });
  });
}
