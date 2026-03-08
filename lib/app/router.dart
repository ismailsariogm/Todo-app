import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/tasks/home_screen.dart';
import '../features/tasks/active_screen.dart';
import '../features/tasks/completed_screen.dart';
import '../features/tasks/trash_screen.dart';
import '../features/tasks/task_form_screen.dart';
import '../features/tasks/task_detail_screen.dart';
import '../features/collaboration/collaboration_screen.dart';
import '../features/collaboration/group_detail_screen.dart';
import '../features/collaboration/community_group_detail_screen.dart';
import '../features/collaboration/community_group_form_screen.dart';
import '../features/collaboration/group_form_screen.dart';
import '../features/collaboration/group_settings_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/profile_screen.dart';
import '../features/auth/auth_provider.dart';

// ─── Route names ──────────────────────────────────────────────────────────
abstract class AppRoutes {
  static const splash = '/';
  static const auth = '/auth';
  static const home = '/home';
  static const active = '/active';
  static const completed = '/completed';
  static const trash = '/trash';
  static const settings = '/settings';
  static const taskForm = '/task/form';
  static const taskDetail = '/task/:id';
  static const collab = '/collab';
  static const groupForm = '/collab/group/form';
  static const communityGroupForm = '/collab/community/form';
  static const communityDetail = '/collab/community/detail';
  static const groupDetail = '/collab/group/detail';
  static const groupSettings = '/collab/group/settings';
  static const profileSettings = '/settings/profile';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  // liveUser, signIn/signOut anında güncellenir → her zaman doğru kaynak
  final liveUser = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isOnSplash  = loc == AppRoutes.splash;
      final isAuthRoute = loc == AppRoutes.auth;

      // Oturum kontrolü henüz bitmedi → splash'te bekle
      if (isOnSplash && authState.isLoading) return null;

      // Sadece liveUser kullan — signOut sonrası authState önbelleğini yok say
      final isAuth = liveUser != null;

      if (isOnSplash) return isAuth ? AppRoutes.home : AppRoutes.auth;
      if (!isAuth && !isAuthRoute) return AppRoutes.auth;
      if (isAuth && isAuthRoute) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const _SplashScreen(),
        redirect: (_, __) => null,
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (_, __) => const AuthScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, state) => _fadeTransition(state, const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.active,
            pageBuilder: (_, state) =>
                _fadeTransition(state, const ActiveScreen()),
          ),
          GoRoute(
            path: AppRoutes.completed,
            pageBuilder: (_, state) =>
                _fadeTransition(state, const CompletedScreen()),
          ),
          GoRoute(
            path: AppRoutes.trash,
            pageBuilder: (_, state) =>
                _fadeTransition(state, const TrashScreen()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (_, state) =>
                _fadeTransition(state, const SettingsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.taskForm,
        builder: (context, state) {
          final taskId = state.uri.queryParameters['taskId'];
          final groupId = state.uri.queryParameters['groupId'];
          return TaskFormScreen(taskId: taskId, groupId: groupId);
        },
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        builder: (context, state) {
          final taskId = state.pathParameters['id']!;
          return TaskDetailScreen(taskId: taskId);
        },
      ),
      GoRoute(
        path: AppRoutes.profileSettings,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.collab,
        builder: (_, __) => const CollaborationScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupForm,
        builder: (context, state) {
          final groupId = state.uri.queryParameters['groupId'];
          return GroupFormScreen(groupId: groupId);
        },
      ),
      GoRoute(
        path: AppRoutes.communityGroupForm,
        builder: (_, __) => const CommunityGroupFormScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.communityDetail}/:id',
        builder: (context, state) {
          final communityId = state.pathParameters['id']!;
          return CommunityGroupDetailScreen(communityId: communityId);
        },
      ),
      GoRoute(
        path: '${AppRoutes.groupDetail}/:id',
        builder: (context, state) {
          final groupId = state.pathParameters['id']!;
          return GroupDetailScreen(groupId: groupId);
        },
      ),
      GoRoute(
        path: '${AppRoutes.groupSettings}/:id',
        builder: (context, state) {
          final groupId = state.pathParameters['id']!;
          return GroupSettingsScreen(groupId: groupId);
        },
      ),
    ],
  );
});

NoTransitionPage<T> _fadeTransition<T>(GoRouterState state, Widget child) {
  return NoTransitionPage<T>(key: state.pageKey, child: child);
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
