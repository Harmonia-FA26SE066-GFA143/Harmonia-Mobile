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

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionManager = ref.read(sessionManagerProvider);

  return GoRouter(
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
          final target = Uri.encodeComponent(state.uri.toString());
          return '/splash?from=$target';
        }
        return null;
      }

      // 2. Unauthenticated: redirect protected routes to /login
      if (status == AuthStatus.unauthenticated) {
        if (!isLoggingIn) {
          return '/login';
        }
        return null;
      }

      // 3. Authenticated: prevent lingering on /login or /splash
      if (status == AuthStatus.authenticated) {
        if (isLoggingIn || isSplash) {
          final from = state.uri.queryParameters['from'];
          if (from != null &&
              from.isNotEmpty &&
              from != '/login' &&
              from != '/splash') {
            return Uri.decodeComponent(from);
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
});
