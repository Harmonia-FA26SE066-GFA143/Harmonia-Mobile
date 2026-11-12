import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/harmonia_logo.dart';
import '../data/auth_dto.dart';
import 'auth_notifier.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _feedbackMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _isSuccess = false;
        _feedbackMessage = 'Vui lòng nhập email hợp lệ.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
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
        .forgotPassword(email: email, platform: platform);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _isSuccess = ok;
      _feedbackMessage = ok
          ? 'Yêu cầu đã được gửi. Vui lòng kiểm tra hòm thư của bạn.'
          : ref.read(authNotifierProvider).errorMessage ??
                'Không thể gửi yêu cầu đặt lại mật khẩu.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Quay lại đăng nhập',
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    const HarmoniaLogo(size: 48),
                    const SizedBox(height: 10),
                    Text(
                      'Harmonia',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ứng dụng đồng hành dành cho Ca viên',
                      style: AppTypography.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Quên mật khẩu?',
                            style: AppTypography.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Nhập email đã đăng ký để nhận hướng dẫn đặt lại mật khẩu.',
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: 20),
                          Text('Email', style: AppTypography.labelLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.email],
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              hintText: 'ten@giaoxu.org',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          if (_feedbackMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _feedbackMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                color: _isSuccess
                                    ? AppColors.statusSuccess
                                    : AppColors.statusDanger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                : const Text('Gửi yêu cầu'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Quay lại đăng nhập'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
