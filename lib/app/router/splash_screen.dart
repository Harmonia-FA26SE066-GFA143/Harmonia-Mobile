import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authNotifierProvider.notifier).restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.music_note_rounded,
                color: AppColors.onPrimary,
                size: 46,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Harmonia Choir',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ứng dụng Phụng vụ Ca đoàn',
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 36),
            if (auth.errorMessage != null && !auth.isLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  auth.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.statusDanger),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).restoreSession(),
                child: const Text('Thử lại'),
              ),
              TextButton(
                onPressed: () => ref.read(sessionManagerProvider).endSession(),
                child: const Text('Đăng nhập lại'),
              ),
            ] else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
