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
import 'main_navigation_shell.dart';

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
  final sessionManager = ref.watch(sessionManagerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final isAuth = sessionManager.status == AuthStatus.authenticated;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isAuth && !isLoggingIn) {
        // If unauthenticated and trying to view protected pages, let demo proceed or redirect
        return null;
      }
      return null;
    },
    routes: [
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
