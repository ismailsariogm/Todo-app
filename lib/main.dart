import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show
        ConsumerWidget,
        ProviderContainer,
        UncontrolledProviderScope,
        WidgetRef;
import 'package:intl/date_symbol_data_local.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'app/providers.dart';
import 'data/repositories/chat_repository.dart';
import 'data/repositories/web_task_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/task_repository.dart';
import 'domain/entities/chat_user_entity.dart';
import 'services/auto_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('tr_TR');
  await initializeDateFormatting('en_US');

  // ── Veritabanından tüm verileri yükle ────────────────────────────────────
  await WebTaskRepository.instance.init();
  await WebProjectRepository.instance.init();
  await _seedDemoFriendsIfNeeded();

  // ── Otomatik senkronizasyonu başlat (her 1 saniyede DB'ye yaz) ───────────
  AutoSyncService.instance.start();

  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).initialize();
  await container.read(localeProvider.notifier).initialize();
  await container.read(profileProvider.notifier).initialize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TodoNoteApp(),
    ),
  );
}

/// One-time seed: creates 3 demo friends for ismailsariogm@gmail.com.
/// Runs only when that account is detected and seed hasn't been applied yet.
Future<void> _seedDemoFriendsIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  final email = prefs.getString('demo_email') ?? '';
  final uid = prefs.getString('demo_uid') ?? '';

  if (email != 'ismailsariogm@gmail.com' || uid.isEmpty) return;
  if (prefs.getBool('demo_friends_seeded') == true) return;

  const friends = [
    (
      id: 'demo_friend_zeynep',
      name: 'Zeynep Arslan',
      email: 'zeynep.arslan@demo.com',
      color: '#CF4DA6',
    ),
    (
      id: 'demo_friend_mert',
      name: 'Mert Kaya',
      email: 'mert.kaya@demo.com',
      color: '#3B82F6',
    ),
    (
      id: 'demo_friend_elif',
      name: 'Elif Demir',
      email: 'elif.demir@demo.com',
      color: '#10B981',
    ),
  ];

  final repo = ChatRepository.instance;
  final now = DateTime.now();

  for (final f in friends) {
    final entity = ChatUserEntity(
      uid: f.id,
      displayName: f.name,
      email: f.email,
      userCode: generateUserCode(f.id),
      avatarColorHex: f.color,
      createdAt: now,
    );
    // Register in global user registry so they can be found by code
    await repo.registerUser(entity);
    // Add to this user's friends list
    await repo.addFriend(uid, entity);
  }

  await prefs.setBool('demo_friends_seeded', true);
}

class TodoNoteApp extends ConsumerWidget {
  const TodoNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'To-Do Note',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr'),
        Locale('en'),
      ],
      routerConfig: router,
    );
  }
}
