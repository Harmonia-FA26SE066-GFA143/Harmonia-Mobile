import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/core_providers.dart';
import '../../core/session/session_manager.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/calendar/presentation/rehearsal_detail_screen.dart';
import '../../features/calendar/presentation/liturgical_event_detail_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/music/presentation/song_detail_screen.dart';
import '../../features/music/presentation/music_library_screen.dart';
import '../../features/music/presentation/music_material_screen.dart';
import '../../features/notifications/presentation/notification_list_screen.dart';
import '../../features/practice/presentation/practice_detail_screen.dart';
import '../../features/practice/presentation/practice_list_screen.dart';
import '../../features/practice/presentation/practice_history_screen.dart';
import '../../features/practice/presentation/practice_submission_detail_screen.dart';
import '../../features/profile/presentation/participation_history_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/music/presentation/interactive_score_screen.dart';
import '../../features/staff_workspace/presentation/staff_chat_screen.dart';
import '../../features/staff_workspace/presentation/staff_practice_screen.dart';
import '../../features/staff_workspace/presentation/staff_rehearsals.dart';
import '../../features/staff_workspace/presentation/staff_reports_screen.dart';
import '../../features/staff_workspace/presentation/staff_roster_screen.dart';
import '../../features/staff_workspace/presentation/staff_program_form.dart';
import '../../features/staff_workspace/presentation/staff_workspace_screen.dart';
import 'main_navigation_shell.dart';
import 'role_routes.dart';
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
  if (!path.startsWith('/') || path.startsWith('//') || path.contains(r'\')) {
    return false;
  }
  final uri = Uri.tryParse(path);
  if (uri == null || uri.hasAuthority || uri.hasScheme) return false;
  final location = uri.path;
  if (location == '/login' ||
      location == '/splash' ||
      location == '/change-password' ||
      location == '/forgot-password' ||
      location == '/reset-password') {
    return false;
  }
  return true;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionManager = ref.read(sessionManagerProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: sessionManager,
    initialLocation: '/splash',
    redirect: (context, state) {
      // Allow /reset-password across all session statuses (initial, unauth, auth)
      if (state.matchedLocation == '/forgot-password' ||
          state.uri.path == '/forgot-password' ||
          state.matchedLocation == '/reset-password' ||
          state.uri.path == '/reset-password') {
        return null;
      }

      final status = sessionManager.status;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      // 1. Session is still initializing / restoring
      if (status == AuthStatus.initial || status == AuthStatus.restoring) {
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

      final isChangePassword = state.matchedLocation == '/change-password';

      final role = sessionManager.role;
      if (role == null) return isLoggingIn ? null : '/login';
      final from = state.uri.queryParameters['from'];
      bool canResume(String? path) =>
          _isValidInternalRoute(path) &&
          roleAllowsRoute(role, Uri.parse(path!));

      if (sessionManager.isPasswordChangeRequired && !isChangePassword) {
        final target = isLoggingIn || isSplash ? from : state.uri.toString();
        return Uri(
          path: '/change-password',
          queryParameters: canResume(target) ? {'from': target!} : null,
        ).toString();
      }

      if (isLoggingIn || isSplash) {
        return canResume(from) ? from! : '/home';
      }
      if (state.uri.path == '/' || !roleAllowsRoute(role, state.uri)) {
        return '/home';
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: '/change-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ChangePasswordScreen(
          isForced: sessionManager.isPasswordChangeRequired,
        ),
      ),
      GoRoute(
        path: '/reset-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final tokenValues = state.uri.queryParametersAll['token'];
          final isDuplicateToken =
              tokenValues != null && tokenValues.length > 1;
          final token = state.uri.queryParameters['token'];
          return ResetPasswordScreen(
            token: token,
            isDuplicateToken: isDuplicateToken,
          );
        },
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(
            navigationShell: navigationShell,
            inMusicLibrary: state.uri.path == '/music-library',
          );
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHome,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    sessionManager.role == MobileRole.choirMember
                    ? const HomeScreen()
                    : StaffHomeScreen(role: sessionManager.role!),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCalendar,
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) =>
                    sessionManager.role == MobileRole.choirMember
                    ? const CalendarScreen()
                    : const StaffProgramsScreen(),
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
              GoRoute(
                path: '/music-library',
                builder: (context, state) => const MusicLibraryScreen(),
              ),
              GoRoute(
                path: '/manage',
                builder: (context, state) => const StaffChoirsScreen(),
              ),
              GoRoute(
                path: '/approvals',
                builder: (context, state) => const StaffApprovalsScreen(),
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
                builder: (context, state) =>
                    sessionManager.role == MobileRole.choirMember
                    ? const ProfileScreen()
                    : StaffAccountScreen(role: sessionManager.role!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/rehearsal/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RehearsalDetailScreen(
          rehearsalId: state.pathParameters['id'] ?? '',
          showOwnAttendance: sessionManager.role == MobileRole.choirMember,
        ),
      ),
      GoRoute(
        path: '/event-detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final role = sessionManager.role!;
          return role == MobileRole.choirMember
              ? LiturgicalEventDetailScreen(eventId: id)
              : StaffEventScreen(eventId: id, role: role);
        },
      ),
      GoRoute(
        path: '/music-material/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => MusicMaterialScreen(
          materialId: state.pathParameters['id'] ?? '',
          songId: state.uri.queryParameters['songId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/song-detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return sessionManager.role == MobileRole.choirMember
              ? SongDetailScreen(songId: id)
              : StaffSongScreen(songId: id);
        },
      ),
      GoRoute(
        path: '/staff-rehearsals',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StaffRehearsalsScreen(
          eventId: state.uri.queryParameters['eventId'],
        ),
      ),
      GoRoute(
        path: '/staff-attendance/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            StaffAttendanceScreen(rehearsalId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/staff-roster/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            StaffRosterScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/staff-participation/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            StaffParticipationScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/staff-demo/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StaffParticipationScreen(
          eventId: state.pathParameters['id']!,
          demo: true,
        ),
      ),
      GoRoute(
        path: '/staff-submissions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StaffSubmissionsScreen(),
      ),
      GoRoute(
        path: '/staff-submission/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            StaffSubmissionScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/staff-chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StaffChatScreen(),
      ),
      GoRoute(
        path: '/staff-chat-new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            const StaffChatScreen(chooseRecipient: true),
      ),
      GoRoute(
        path: '/staff-chat/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StaffThreadScreen(
          userId: state.pathParameters['id']!,
          name: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/staff-reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            StaffReportsScreen(role: sessionManager.role!),
      ),
      GoRoute(
        path: '/staff-scores/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            StaffScoresScreen(songId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/interactive-score/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            InteractiveScoreScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/program-new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StaffProgramForm(),
      ),
      GoRoute(
        path: '/song-list/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            StaffSongListScreen(listId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/director-note/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            StaffNoteScreen(noteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/practice-detail/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PracticeDetailScreen(assignmentId: id);
        },
      ),
      GoRoute(
        path: '/practice-history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PracticeHistoryScreen(),
      ),
      GoRoute(
        path: '/practice-submission/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PracticeSubmissionDetailScreen(submissionId: id);
        },
      ),
      GoRoute(
        path: '/profile/history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ParticipationHistoryScreen(),
      ),
    ],
  );
  ref.onDispose(() => router.dispose());
  return router;
});
