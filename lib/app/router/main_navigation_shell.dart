import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/core_providers.dart';
import '../../core/session/session_manager.dart';
import '../../features/notifications/presentation/notification_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/member_choir_visuals.dart';
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

    final isMemberHome =
        role == MobileRole.choirMember && navigationShell.currentIndex == 0;
    final memberChoirScreen =
        role == MobileRole.choirMember && navigationShell.currentIndex < 3;
    final flat =
        memberChoirScreen ||
        inMusicLibrary ||
        navigationShell.currentIndex >= 2;
    final radius = BorderRadius.circular(flat ? 0 : 32);
    final activeColor = isMemberHome
        ? MemberChoirStyle.accent
        : memberChoirScreen
        ? MemberChoirStyle.wine
        : AppColors.primary;
    const memberHomeMuted = Color(0xFF76767E);
    const memberHomeHover = Color(0xFF111C2D);
    const memberHomeBorder = Color(0xFFE6E1D8);
    final navigationTheme = NavigationBarTheme.of(context);
    final labelStyle = navigationTheme.labelTextStyle;
    final iconTheme = navigationTheme.iconTheme;

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
            border: Border.all(
              color: isMemberHome ? memberHomeBorder : AppColors.border,
            ),
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
            child: NavigationBarTheme(
              data: isMemberHome
                  ? navigationTheme.copyWith(
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        final base =
                            labelStyle?.resolve(states) ??
                            AppTypography.labelSmall;
                        if (states.contains(WidgetState.selected)) {
                          return base.copyWith(
                            color: activeColor,
                            fontWeight: FontWeight.w700,
                          );
                        }
                        if (states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)) {
                          return base.copyWith(color: memberHomeHover);
                        }
                        return base.copyWith(color: memberHomeMuted);
                      }),
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        final base =
                            iconTheme?.resolve(states) ??
                            const IconThemeData(size: 26);
                        if (states.contains(WidgetState.selected)) {
                          return base.copyWith(color: activeColor);
                        }
                        if (states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)) {
                          return base.copyWith(color: memberHomeHover);
                        }
                        return base.copyWith(color: memberHomeMuted);
                      }),
                    )
                  : memberChoirScreen
                  ? navigationTheme.copyWith(
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        final base =
                            labelStyle?.resolve(states) ??
                            AppTypography.labelSmall;
                        return states.contains(WidgetState.selected)
                            ? base.copyWith(color: activeColor)
                            : base;
                      }),
                    )
                  : navigationTheme,
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
                indicatorColor: memberChoirScreen
                    ? MemberChoirStyle.blush
                    : AppColors.primarySoft,
                indicatorShape: const StadiumBorder(),
                elevation: 0,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded, color: activeColor),
                    label: 'Trang chủ',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(
                      Icons.calendar_month_rounded,
                      color: activeColor,
                    ),
                    label: role == MobileRole.choirMember
                        ? 'Lịch tuần'
                        : 'Lịch',
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
                    _ when inMusicLibrary => NavigationDestination(
                      icon: const Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(
                        Icons.menu_book_rounded,
                        color: activeColor,
                      ),
                      label: 'Thư viện',
                    ),
                    _ => NavigationDestination(
                      icon: Icon(
                        memberChoirScreen
                            ? Icons.headphones_outlined
                            : Icons.mic_none_rounded,
                      ),
                      selectedIcon: Icon(
                        memberChoirScreen
                            ? Icons.headphones_rounded
                            : Icons.mic_rounded,
                        color: activeColor,
                      ),
                      label: 'Luyện tập',
                    ),
                  },
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: notificationState.unreadCount > 0,
                      label: Text('${notificationState.unreadCount}'),
                      backgroundColor: isMemberHome
                          ? AppColors.error
                          : AppColors.primary,
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: notificationState.unreadCount > 0,
                      label: Text('${notificationState.unreadCount}'),
                      backgroundColor: isMemberHome
                          ? AppColors.error
                          : AppColors.primary,
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
      ),
    );
  }
}
