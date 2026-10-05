import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../core/session/session_manager.dart';
import '../features/notifications/presentation/notification_notifier.dart';
import '../features/profile/data/profile_repository.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class HarmoniaApp extends ConsumerWidget {
  const HarmoniaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final signalRService = ref.watch(signalRServiceProvider);

    // Coordinate SignalR and notification state with session lifecycle per Rule 04 & 06
    ref.listen<AuthStatus>(sessionManagerProvider.select((s) => s.status), (
      previous,
      next,
    ) {
      if (next == AuthStatus.authenticated) {
        signalRService.connect();
        ref.read(notificationNotifierProvider.notifier).reconnectRealtime();
        ref.invalidate(currentMemberProfileProvider);
      } else if (next == AuthStatus.unauthenticated) {
        signalRService.stop();
        ref.read(notificationNotifierProvider.notifier).reset();
        ref.invalidate(currentMemberProfileProvider);
      }
    });

    return MaterialApp.router(
      title: 'Harmonia Choir',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      locale: const Locale('vi', 'VN'),
    );
  }
}
