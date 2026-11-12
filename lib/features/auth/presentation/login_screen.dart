import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/harmonia_logo.dart';
import '../../../app/widgets/stitch_entrance.dart';
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
    if (ref.read(authNotifierProvider).isLoading ||
        !_formKey.currentState!.validate()) {
      return;
    }

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

    await ref
        .read(authNotifierProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          platform: platform,
        );
  }

  void _handleGoogleSignIn() async {
    if (ref.read(authNotifierProvider).isLoading) return;

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

    await ref
        .read(authNotifierProvider.notifier)
        .signInWithGoogle(platform: platform);
  }

  void _openForgotPasswordScreen() {
    final email = _emailController.text.trim();
    final location = Uri(
      path: '/forgot-password',
      queryParameters: email.isEmpty ? null : {'email': email},
    );
    context.push(location.toString());
  }

  InputDecoration _field(String hint, IconData icon, {Widget? trailing}) {
    final shape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE8E2DB)),
    );
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8F6F3),
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary),
      suffixIcon: trailing,
      enabledBorder: shape,
      focusedBorder: shape.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  void _clearError(String _) {
    if (ref.read(authNotifierProvider).errorMessage != null) {
      ref.read(authNotifierProvider.notifier).clearErrors();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final type = Theme.of(context).textTheme
        .apply(fontFamily: 'Plus Jakarta Sans');
    const white = Colors.white;
    final titleScale = MediaQuery.textScalerOf(context).scale(16) / 16;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F3F5),
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 294 + 100 * (titleScale - 1).clamp(0.0, 1.5),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.headerWine,
                      AppColors.primary,
                      AppColors.primaryHover,
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(36),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: white.withValues(alpha: .16),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: white.withValues(alpha: .28),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              child: Text(
                                'HỆ THỐNG CA ĐOÀN PHỤNG VỤ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const HarmoniaLogo(size: 44),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Harmonia',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineLarge.copyWith(
                                  color: white,
                                  fontFamily: 'Playfair Display',
                                  fontSize: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Chào mừng trở lại!',
                          textAlign: TextAlign.center,
                          style: AppTypography.headlineSmall.copyWith(
                            color: white,
                            fontFamily: 'Playfair Display',
                            fontSize: 23,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đăng nhập tài khoản Harmonia',
                          textAlign: TextAlign.center,
                          style: type.bodyMedium?.copyWith(
                            color: AppColors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 20),
                        StitchEntrance(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: white,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x180F172A),
                                  blurRadius: 24,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Theme(
                                data: Theme.of(context)
                                    .copyWith(textTheme: type),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (auth.errorMessage
                                          case final error?) ...[
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.statusDangerSoft,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            error,
                                            style: type.bodySmall?.copyWith(
                                              color: AppColors.onErrorContainer,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                      Text(
                                        'EMAIL TÀI KHOẢN',
                                        style: type.labelMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        decoration: _field(
                                          'Nhập email của bạn',
                                          Icons.mail_outline_rounded,
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Vui lòng nhập email.';
                                          }
                                          if (!value.contains('@') ||
                                              !value.contains('.')) {
                                            return 'Email không đúng định dạng.';
                                          }
                                          return null;
                                        },
                                        onChanged: _clearError,
                                      ),
                                      const SizedBox(height: 15),
                                      Text(
                                        'MẬT KHẨU TRUY CẬP',
                                        style: type.labelMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _isPasswordObscured,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _submitLogin(),
                                        decoration: _field(
                                          'Nhập mật khẩu của bạn',
                                          Icons.lock_outline_rounded,
                                          trailing: IconButton(
                                            tooltip: _isPasswordObscured
                                                ? 'Hiện mật khẩu'
                                                : 'Ẩn mật khẩu',
                                            onPressed: () => setState(
                                              () => _isPasswordObscured =
                                                  !_isPasswordObscured,
                                            ),
                                            icon: Icon(
                                              _isPasswordObscured
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                            ),
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null || value.isEmpty
                                            ? 'Vui lòng nhập mật khẩu.'
                                            : null,
                                        onChanged: _clearError,
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _openForgotPasswordScreen,
                                          child: const Text('Quên mật khẩu?'),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: auth.isLoading
                                            ? null
                                            : _submitLogin,
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size.fromHeight(
                                            54,
                                          ),
                                        ),
                                        child: auth.isLoading
                                            ? const SizedBox.square(
                                                dimension: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      'Đăng nhập',
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 19,
                                                  ),
                                                ],
                                              ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                        child: Row(
                                          children: [
                                            const Expanded(child: Divider()),
                                            Flexible(
                                              flex: 6,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                    ),
                                                child: Text(
                                                  'HOẶC TIẾP TỤC VỚI',
                                                  textAlign: TextAlign.center,
                                                  style: type.labelSmall
                                                      ?.copyWith(
                                                        color: AppColors.muted,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            const Expanded(child: Divider()),
                                          ],
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: auth.isLoading
                                            ? null
                                            : _handleGoogleSignIn,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.onSurface,
                                          backgroundColor: const Color(
                                            0xFFF8F6F3,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.g_mobiledata_rounded,
                                          size: 25,
                                          color: Color(0xFF4285F4),
                                        ),
                                        label: const Text(
                                          'Đăng nhập với Google',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Tài khoản do Ca trưởng hoặc Quản trị ca đoàn cấp.\nNếu gặp sự cố, vui lòng liên hệ Ban điều hành.',
                          textAlign: TextAlign.center,
                          style: type.bodySmall?.copyWith(
                            color: AppColors.muted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
