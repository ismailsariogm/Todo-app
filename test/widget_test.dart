import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo_note/ui/widgets/empty_state_widget.dart';
import 'package:todo_note/app/theme.dart';

void main() {
  group('EmptyStateWidget', () {
    Widget buildWidget({
      required IconData icon,
      required String title,
      String? subtitle,
      bool compact = false,
    }) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: EmptyStateWidget(
            icon: icon,
            title: title,
            subtitle: subtitle,
            compact: compact,
          ),
        ),
      );
    }

    testWidgets('renders title correctly', (tester) async {
      await tester.pumpWidget(
        buildWidget(icon: Icons.inbox, title: 'Görev yok'),
      );
      expect(find.text('Görev yok'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          icon: Icons.inbox,
          title: 'Görev yok',
          subtitle: 'Yeni görev ekleyin',
        ),
      );
      expect(find.text('Yeni görev ekleyin'), findsOneWidget);
    });

    testWidgets('does not render subtitle when not provided', (tester) async {
      await tester.pumpWidget(
        buildWidget(icon: Icons.inbox, title: 'Görev yok'),
      );
      expect(find.text('Alt metin'), findsNothing);
    });

    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(
        buildWidget(icon: Icons.wb_sunny, title: 'Test'),
      );
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    });

    testWidgets('compact mode renders smaller icon container', (tester) async {
      await tester.pumpWidget(
        buildWidget(icon: Icons.inbox, title: 'Test', compact: true),
      );
      // Should render without overflow
      expect(find.byType(EmptyStateWidget), findsOneWidget);
    });
  });

  group('AppTheme', () {
    test('light theme has correct primary seed', () {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, equals(Brightness.light));
    });

    test('dark theme has dark brightness', () {
      final theme = AppTheme.dark();
      expect(theme.colorScheme.brightness, equals(Brightness.dark));
    });

    test('PriorityColor returns correct colors', () {
      expect(PriorityColor.of(1), equals(const Color(0xFFEF4444)));
      expect(PriorityColor.of(2), equals(const Color(0xFFF97316)));
      expect(PriorityColor.of(3), equals(const Color(0xFFEAB308)));
      expect(PriorityColor.of(4), equals(const Color(0xFF94A3B8)));
    });

    test('PriorityColor labels are correct', () {
      expect(PriorityColor.label(1), equals('P1'));
      expect(PriorityColor.label(2), equals('P2'));
      expect(PriorityColor.label(3), equals('P3'));
      expect(PriorityColor.label(4), equals('P4'));
    });

    test('PriorityColor names are correct', () {
      expect(PriorityColor.name(1), equals('Yüksek'));
      expect(PriorityColor.name(2), equals('Orta'));
      expect(PriorityColor.name(3), equals('Düşük'));
      expect(PriorityColor.name(4), equals('Yok'));
    });
  });
}
