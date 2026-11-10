import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/stitch_entrance.dart';

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
    final error = auth.isLoading ? null : auth.errorMessage;
    const gold = Color(0xFFFFD678);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF860022),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF3B5D), AppColors.primary, Color(0xFF820021)],
              stops: [0, .45, 1],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 42).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0x33820021),
                            border: Border.all(
                              color: gold.withValues(alpha: .55),
                            ),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 7,
                              horizontal: 14,
                            ),
                            child: Text(
                              'MÙA PHỤNG VỤ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: StitchEntrance(
                          child: Column(
                            children: [
                              ExcludeSemantics(
                                child: Container(
                                  width: 132,
                                  height: 132,
                                  padding: const EdgeInsets.all(17),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: .16),
                                    border: Border.all(
                                      color: gold.withValues(alpha: .65),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(26),
                                    child: Image.asset(
                                      'assets/images/harmonia_logo.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Harmonia',
                                style: AppTypography.headlineLarge.copyWith(
                                  color: Colors.white,
                                  fontFamily: 'Playfair Display',
                                  fontSize: 38,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'HỆ THỐNG QUẢN LÝ THÁNH NHẠC & CA ĐOÀN',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: gold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: .6,
                                ),
                              ),
                              const SizedBox(height: 26),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .10),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .22),
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Text(
                                      '“Hát là cầu nguyện hai lần”',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    SizedBox(height: 7),
                                    Text(
                                      'THÁNH AUGUSTINÔ',
                                      style: TextStyle(
                                        color: gold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (error != null) ...[
                            Text(
                              error,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: gold,
                                foregroundColor: AppColors.onSurface,
                              ),
                              onPressed: () => ref
                                  .read(authNotifierProvider.notifier)
                                  .restoreSession(),
                              child: const Text('Thử lại'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  ref.read(sessionManagerProvider).endSession(),
                              child: const Text('Đăng nhập lại'),
                            ),
                          ] else ...[
                            const Text(
                              'Đang khôi phục phiên…',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(8),
                              color: gold,
                              backgroundColor: Colors.white.withValues(
                                alpha: .24,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          const Text(
                            'Đồng hành cùng Phụng vụ Thánh & Ca đoàn Giáo hội',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFFFDCE5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
