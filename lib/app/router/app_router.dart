import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/core_providers.dart';
import '../../core/session/session_manager.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/calendar/presentation/liturgical_event_detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/music/presentation/song_detail_screen.dart';
import '../../features/notifications/presentation/notification_list_screen.dart';
import '../../features/practice/presentation/practice_detail_screen.dart';
import '../../features/practice/presentation/practice_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../app_env.dart';
import 'main_navigation_shell.dart';
import 'splash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHome = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorCalendar = GlobalKey<NavigatorState>(
  debugLabel: 'shellCalendar',
);
final _shellNavigatorPractice = GlobalKey<NavigatorState>(
  debugLabel: 'shellPractice',
);
final _shellNavigatorNotifications = GlobalKey<NavigatorState>(
  debugLabel: 'shellNotifications',
);
final _shellNavigatorProfile = GlobalKey<NavigatorState>(
  debugLabel: 'shellProfile',
);

bool _isValidInternalRoute(String? path) {
  if (path == null || path.isEmpty) return false;
  // Must be an internal relative path starting with '/' and not '//'
  if (!path.startsWith('/') || path.startsWith('//')) return false;
  final uri = Uri.tryParse(path);
  final location = uri?.path ?? path;
  if (location == '/login' || location == '/splash') return false;
  return true;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionManager = ref.read(sessionManagerProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: sessionManager,
    initialLocation: AppEnv.useMock ? '/home' : '/splash',
    redirect: (context, state) {
      if (AppEnv.useMock) {
        // In demo mode, bypass login and allow exploring all screens
        return null;
      }

      final status = sessionManager.status;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      // 1. Session is still initializing / restoring
      if (status == AuthStatus.initial) {
        if (!isSplash) {
          final target = state.uri.toString();
          if (_isValidInternalRoute(target)) {
            return '/splash?from=${Uri.encodeComponent(target)}';
          }
          return '/splash';
        }
        return null;
      }

      // 2. Unauthenticated: redirect protected routes to /login, preserving deep link
      if (status == AuthStatus.unauthenticated) {
        if (!isLoggingIn) {
          final existingFrom = state.uri.queryParameters['from'];
          if (existingFrom != null && _isValidInternalRoute(existingFrom)) {
            return '/login?from=${Uri.encodeComponent(existingFrom)}';
          }
          final target = state.uri.toString();
          if (_isValidInternalRoute(target)) {
            return '/login?from=${Uri.encodeComponent(target)}';
          }
          return '/login';
        }
        return null;
      }

      // 3. Authenticated: prevent lingering on /login or /splash and return to deep link
      if (status == AuthStatus.authenticated) {
        if (isLoggingIn || isSplash) {
          // Note: state.uri.queryParameters already decodes the parameter once.
          // Do NOT call Uri.decodeComponent a second time per Rule 04 / Prompt instructions.
          final from = state.uri.queryParameters['from'];
          if (_isValidInternalRoute(from)) {
            return from!;
          }
          return '/home';
        }
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHome,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCalendar,
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorPractice,
            routes: [
              GoRoute(
                path: '/practice',
                builder: (context, state) => const PracticeListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorNotifications,
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorProfile,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/event-detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return LiturgicalEventDetailScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/song-detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return SongDetailScreen(songId: id);
        },
      ),
      GoRoute(
        path: '/practice-detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PracticeDetailScreen(assignmentId: id);
        },
      ),
    ],
  );
  ref.onDispose(() => router.dispose());
  return router;
});
