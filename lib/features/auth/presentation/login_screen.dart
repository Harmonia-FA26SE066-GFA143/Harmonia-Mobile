import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_env.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/core_providers.dart';
import '../data/auth_dto.dart';
import 'auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    DevicePlatform platform;
    try {
      if (Platform.isAndroid) {
        platform = DevicePlatform.android;
      } else if (Platform.isIOS) {
        platform = DevicePlatform.ios;
      } else {
        platform = DevicePlatform.web;
      }
    } catch (_) {
      platform = DevicePlatform.android;
    }

    final success = await ref
        .read(authNotifierProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          platform: platform,
        );

    if (success && mounted) {
      final from = GoRouterState.of(context).uri.queryParameters['from'];
      if (from != null &&
          from.startsWith('/') &&
          !from.startsWith('//') &&
          from != '/login' &&
          from != '/splash') {
        context.go(from);
      } else {
        context.go('/home');
      }
    }
  }

  void _showGoogleLoginSheet() {
    final tokenController = TextEditingController();
    bool isSubmitting = false;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.g_mobiledata_rounded,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đăng nhập với Google',
                                style: AppTypography.titleLarge,
                              ),
                              Text(
                                'Tích hợp POST /api/auth/google',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (AppEnv.googleClientId.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.statusInfoSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.statusInfo.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'Máy chủ Harmonia đã hỗ trợ xác thực Google bằng ID Token. Để tự động mở hộp thoại chọn tài khoản Google trên máy này, cần cấu hình GOOGLE_CLIENT_ID trong môi trường ứng dụng.\n\nBạn có thể dán Google ID Token bên dưới để đăng nhập trực tiếp:',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text('Google ID Token', style: AppTypography.labelMedium),
                    const SizedBox(height: 6),
                    TextField(
                      controller: tokenController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Dán Google ID Token nhận được từ Google Sign-In...',
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        localError!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.statusDanger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final token = tokenController.text.trim();
                              if (token.isEmpty) {
                                setModalState(() {
                                  localError =
                                      'Vui lòng nhập hoặc dán Google ID Token.';
                                });
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                                localError = null;
                              });

                              DevicePlatform platform;
                              try {
                                if (Platform.isAndroid) {
                                  platform = DevicePlatform.android;
                                } else if (Platform.isIOS) {
                                  platform = DevicePlatform.ios;
                                } else {
                                  platform = DevicePlatform.web;
                                }
                              } catch (_) {
                                platform = DevicePlatform.android;
                              }

                              final nav = Navigator.of(context);
                              final router = GoRouter.of(this.context);
                              final from = GoRouterState.of(this.context)
                                  .uri
                                  .queryParameters['from'];

                              final success = await ref
                                  .read(authNotifierProvider.notifier)
                                  .loginWithGoogle(
                                    idToken: token,
                                    platform: platform,
                                  );

                              if (success && mounted) {
                                nav.pop();
                                if (from != null &&
                                    from.startsWith('/') &&
                                    !from.startsWith('//') &&
                                    from != '/login' &&
                                    from != '/splash') {
                                  router.go(from);
                                } else {
                                  router.go('/home');
                                }
                              } else {
                                setModalState(() {
                                  isSubmitting = false;
                                  localError =
                                      ref
                                          .read(authNotifierProvider)
                                          .errorMessage ??
                                      'Đăng nhập Google không thành công.';
                                });
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Xác thực và Đăng nhập'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showForgotPasswordSheet() {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool isSubmitting = false;
    String? feedbackMessage;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Quên mật khẩu', style: AppTypography.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Nhập email tài khoản để nhận liên kết đặt lại mật khẩu từ máy chủ Harmonia.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'cavien@example.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    if (feedbackMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        feedbackMessage!,
                        style: AppTypography.bodySmall.copyWith(
                          color: isSuccess
                              ? AppColors.statusSuccess
                              : AppColors.statusDanger,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final email = emailController.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                setModalState(() {
                                  feedbackMessage =
                                      'Vui lòng nhập email hợp lệ.';
                                  isSuccess = false;
                                });
                                return;
                              }

                              setModalState(() {
                                isSubmitting = true;
                                feedbackMessage = null;
                              });

                              DevicePlatform platform;
                              try {
                                if (Platform.isAndroid) {
                                  platform = DevicePlatform.android;
                                } else if (Platform.isIOS) {
                                  platform = DevicePlatform.ios;
                                } else {
                                  platform = DevicePlatform.web;
                                }
                              } catch (_) {
                                platform = DevicePlatform.android;
                              }

                              final ok = await ref
                                  .read(authNotifierProvider.notifier)
                                  .forgotPassword(
                                    email: email,
                                    platform: platform,
                                  );

                              setModalState(() {
                                isSubmitting = false;
                                if (ok) {
                                  isSuccess = true;
                                  feedbackMessage = 'Yêu cầu đã được gửi. Vui lòng kiểm tra hòm thư của bạn.';
                                } else {
                                  isSuccess = false;
                                  feedbackMessage =
                                      ref
                                          .read(authNotifierProvider)
                                          .errorMessage ??
                                      'Không thể gửi yêu cầu đặt lại mật khẩu.';
                                }
                              });
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Gửi yêu cầu đặt lại mật khẩu'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Harmonia App Emblem / Logo
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: AppColors.onPrimary,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title & Description
                    Text(
                      'Harmonia Choir',
                      style: AppTypography.headlineLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ứng dụng đồng hành dành cho Ca viên',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),

                    // Error banner
                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.onErrorContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email Field
                    Text('Email tài khoản', style: AppTypography.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'cavien@example.com',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập email.';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Email không đúng định dạng.';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (authState.errorMessage != null) {
                          ref.read(authNotifierProvider.notifier).clearErrors();
                        }
                      },
                    ),
                    const SizedBox(height: 18),

                    // Password Field
                    Text('Mật khẩu', style: AppTypography.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isPasswordObscured,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitLogin(),
                      decoration: InputDecoration(
                        hintText: 'Nhập mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.muted,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordObscured = !_isPasswordObscured;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập mật khẩu.';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (authState.errorMessage != null) {
                          ref.read(authNotifierProvider.notifier).clearErrors();
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _showForgotPasswordSheet,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.primary,
                        ),
                        child: Text(
                          'Quên mật khẩu?',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login Button
                    ElevatedButton(
                      onPressed: authState.isLoading ? null : _submitLogin,
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Đăng nhập'),
                    ),
                    const SizedBox(height: 20),

                    // Divider "hoặc"
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'HOẶC',
                            style: AppTypography.labelSmall.copyWith(
                              letterSpacing: 1.0,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Google Login Button (connected to Google ID Token flow)
                    OutlinedButton.icon(
                      onPressed: _showGoogleLoginSheet,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                      label: const Text('Đăng nhập với Google'),
                    ),

                    if (AppEnv.useMock) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          ref
                              .read(sessionManagerProvider)
                              .markAuthenticated(role: 'ChoirMember');
                          context.go('/home');
                        },
                        icon: const Icon(Icons.science_outlined, size: 18),
                        label: const Text(
                          'Truy cập Demo (Không cần đăng nhập)',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Footer notice
                    Text(
                      'Tài khoản do Ca trưởng hoặc Quản trị ca đoàn cấp.\nNếu gặp sự cố, vui lòng liên hệ Ban điều hành.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
