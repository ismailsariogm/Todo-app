import 'package:flutter_test/flutter_test.dart';
import 'package:todo_note/domain/entities/filter_entity.dart';

void main() {
  group('TaskFilter', () {
    test('default filter has no active filters', () {
      const filter = TaskFilter();
      expect(filter.hasActiveFilters, isFalse);
    });

    test('filter with dateFilter is active', () {
      const filter = TaskFilter(dateFilter: DateFilter.today);
      expect(filter.hasActiveFilters, isTrue);
    });

    test('filter with priority is active', () {
      const filter = TaskFilter(priority: 1);
      expect(filter.hasActiveFilters, isTrue);
    });

    test('filter with labels is active', () {
      const filter = TaskFilter(labels: ['work']);
      expect(filter.hasActiveFilters, isTrue);
    });

    test('filter with searchQuery is active', () {
      const filter = TaskFilter(searchQuery: 'test');
      expect(filter.hasActiveFilters, isTrue);
    });

    test('copyWith updates specific fields', () {
      const original = TaskFilter(priority: 2);
      final updated = original.copyWith(dateFilter: DateFilter.today);
      expect(updated.priority, equals(2));
      expect(updated.dateFilter, equals(DateFilter.today));
    });

    test('copyWith clearPriority sets priority to null', () {
      const original = TaskFilter(priority: 1);
      final cleared = original.copyWith(clearPriority: true);
      expect(cleared.priority, isNull);
    });

    test('reset returns default filter', () {
      const original = TaskFilter(
        priority: 1,
        dateFilter: DateFilter.overdue,
        labels: ['work'],
      );
      final reset = original.reset();
      expect(reset.hasActiveFilters, isFalse);
    });

    test('toJson / fromJson round-trip', () {
      const original = TaskFilter(
        dateFilter: DateFilter.next7days,
        priority: 2,
        labels: ['work', 'personal'],
        searchQuery: 'flutter',
      );
      final json = original.toJson();
      final restored = TaskFilter.fromJson(json);
      expect(restored.dateFilter, equals(original.dateFilter));
      expect(restored.priority, equals(original.priority));
      expect(restored.labels, equals(original.labels));
      expect(restored.searchQuery, equals(original.searchQuery));
    });

    test('toJsonString / fromJsonString round-trip', () {
      const original = TaskFilter(
        dateFilter: DateFilter.today,
        statusFilter: StatusFilter.active,
      );
      final str = original.toJsonString();
      final restored = TaskFilter.fromJsonString(str);
      expect(restored.dateFilter, equals(DateFilter.today));
      expect(restored.statusFilter, equals(StatusFilter.active));
    });
  });
}
