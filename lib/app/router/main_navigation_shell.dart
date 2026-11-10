import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/core_providers.dart';
import '../../core/session/session_manager.dart';
import '../../features/notifications/presentation/notification_notifier.dart';
import '../theme/app_colors.dart';
import 'role_routes.dart';

class MainNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  final bool inMusicLibrary;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
    this.inMusicLibrary = false,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionManagerProvider.select((s) => s.role));
    final notificationState = ref.watch(notificationNotifierProvider);

    final flat = inMusicLibrary || navigationShell.currentIndex >= 2;
    final radius = BorderRadius.circular(flat ? 0 : 32);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: flat
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x100F172A),
                blurRadius: 24,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: NavigationBar(
              height: flat ? 68 : 76,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                if (index == 2 && role != null) {
                  context.go(
                    inMusicLibrary && role == MobileRole.choirMember
                        ? '/music-library'
                        : workspacePath(role),
                  );
                } else {
                  _onTap(index);
                }
              },
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              indicatorColor: AppColors.primarySoft,
              indicatorShape: const StadiumBorder(),
              elevation: 0,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(
                    Icons.home_rounded,
                    color: AppColors.primary,
                  ),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_month_outlined),
                  selectedIcon: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                  ),
                  label: role == MobileRole.choirMember ? 'Lịch tuần' : 'Lịch',
                ),
                switch (role) {
                  MobileRole.choirDirector => const NavigationDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(
                      Icons.groups_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Quản lý',
                  ),
                  MobileRole.parishPriest => const NavigationDestination(
                    icon: Icon(Icons.fact_check_outlined),
                    selectedIcon: Icon(
                      Icons.fact_check_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Phê duyệt',
                  ),
                  _ when inMusicLibrary => const NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Thư viện',
                  ),
                  _ => const NavigationDestination(
                    icon: Icon(Icons.mic_none_rounded),
                    selectedIcon: Icon(
                      Icons.mic_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Luyện tập',
                  ),
                },
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: notificationState.unreadCount > 0,
                    label: Text('${notificationState.unreadCount}'),
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: notificationState.unreadCount > 0,
                    label: Text('${notificationState.unreadCount}'),
                    backgroundColor: AppColors.primary,
                    child: const Icon(
                      Icons.notifications_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  label: 'Thông báo',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                  ),
                  label: 'Cá nhân',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
