import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/core_providers.dart';
import '../data/auth_dto.dart';
import 'auth_notifier.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? token;
  final bool isDuplicateToken;

  const ResetPasswordScreen({
    super.key,
    this.token,
    this.isDuplicateToken = false,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isNewPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _isSubmittedSuccessfully = false;
  bool _isSubmitting = false;
  int _currentSubmissionId = 0;
  late AuthNotifier _authNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authNotifier = ref.read(authNotifierProvider.notifier);
  }

  @override
  void didUpdateWidget(ResetPasswordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != oldWidget.token ||
        widget.isDuplicateToken != oldWidget.isDuplicateToken) {
      _currentSubmissionId++;
      _isSubmitting = false;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _formKey.currentState?.reset();
      _isSubmittedSuccessfully = false;
      // Immediately invalidate in-flight reset requests in AuthNotifier so late responses are dropped
      _authNotifier.invalidateResetPasswordRequests();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _authNotifier.cancelResetPassword();
        }
      });
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _authNotifier.cancelResetPassword();
    super.dispose();
  }

  bool get _isTokenInvalid {
    if (widget.isDuplicateToken) return true;
    final token = widget.token;
    return token == null || token.trim().isEmpty;
  }

  String? get _tokenErrorMessage {
    if (widget.isDuplicateToken) {
      return 'Liên kết đặt lại mật khẩu không hợp lệ do chứa nhiều mã xác thực trùng lặp. Vui lòng yêu cầu gửi lại email mới.';
    }
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      return 'Liên kết đặt lại mật khẩu không hợp lệ hoặc thiếu mã xác thực. Vui lòng yêu cầu gửi lại email mới.';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu mới.';
    }
    if (value.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự.';
    }
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
    final hasDigit = RegExp(r'[0-9]').hasMatch(value);
    if (!hasLetter || !hasDigit) {
      return 'Mật khẩu phải bao gồm cả chữ và số.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng xác nhận mật khẩu mới.';
    }
    if (value != _newPasswordController.text) {
      return 'Mật khẩu xác nhận không khớp.';
    }
    return null;
  }

  void _submitResetPassword() async {
    final authState = ref.read(authNotifierProvider);
    if (_isSubmitting || authState.isLoading) return;
    if (_isTokenInvalid) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final token = widget.token!;
    // Do NOT trim passwords entered by user
    final newPassword = _newPasswordController.text;

    final submissionId = ++_currentSubmissionId;
    _isSubmitting = true;

    try {
      final success = await ref
          .read(authNotifierProvider.notifier)
          .resetPassword(token: token, newPassword: newPassword);

      if (!mounted || submissionId != _currentSubmissionId) return;

      if (success) {
        // Clear any existing active session locally so navigation to /login will not bounce back to /home
        await ref.read(sessionManagerProvider).endSession();
        if (!mounted || submissionId != _currentSubmissionId) return;
        setState(() {
          _isSubmittedSuccessfully = true;
        });
      }
    } finally {
      if (mounted && submissionId == _currentSubmissionId) {
        _isSubmitting = false;
      }
    }
  }

  void _showForgotPasswordSheet() {
    final emailController = TextEditingController();
    bool isSubmitting = false;
    String? feedbackMessage;
    bool isSuccess = false;
    bool isSheetMounted = true;
    final authNotifier = ref.read(authNotifierProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
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
                    Text(
                      'Yêu cầu gửi lại email',
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nhập email tài khoản để nhận liên kết đặt lại mật khẩu mới.',
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
                              FocusScope.of(modalContext).unfocus();
                              final email = emailController.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                if (isSheetMounted && modalContext.mounted) {
                                  setModalState(() {
                                    feedbackMessage =
                                        'Vui lòng nhập email hợp lệ.';
                                    isSuccess = false;
                                  });
                                }
                                return;
                              }

                              if (isSheetMounted && modalContext.mounted) {
                                setModalState(() {
                                  isSubmitting = true;
                                  feedbackMessage = null;
                                });
                              }

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

                              final ok = await authNotifier.forgotPassword(
                                email: email,
                                platform: platform,
                              );

                              if (!isSheetMounted || !modalContext.mounted) {
                                return;
                              }

                              final currentError = mounted
                                  ? ref.read(authNotifierProvider).errorMessage
                                  : null;

                              if (isSheetMounted && modalContext.mounted) {
                                setModalState(() {
                                  isSubmitting = false;
                                  if (ok) {
                                    isSuccess = true;
                                    feedbackMessage = 'Yêu cầu đã được gửi. Vui lòng kiểm tra hòm thư của bạn.';
                                  } else {
                                    isSuccess = false;
                                    feedbackMessage = currentError ?? 'Không thể gửi yêu cầu đặt lại mật khẩu.';
                                  }
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
                          : const Text('Gửi email đặt lại mật khẩu'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      isSheetMounted = false;
      emailController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.onSurface,
          ),
          onPressed: () {
            _authNotifier.cancelResetPassword();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: _buildContent(authState),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AuthState authState) {
    if (_isSubmittedSuccessfully) {
      return _buildSuccessState();
    }

    if (_isTokenInvalid) {
      return _buildInvalidTokenState();
    }

    return _buildFormState(authState);
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.statusSuccessSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.statusSuccess.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.statusSuccess,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Đặt lại mật khẩu thành công!',
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.statusSuccess,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Mật khẩu tài khoản của bạn đã được cập nhật thành công. Vui lòng đăng nhập lại bằng mật khẩu mới để tiếp tục sử dụng Harmonia.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        ElevatedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Đăng nhập ngay'),
        ),
      ],
    );
  }

  Widget _buildInvalidTokenState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.statusDangerSoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.statusDanger.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.link_off_rounded,
              color: AppColors.statusDanger,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Liên kết không hợp lệ',
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.statusDanger,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _tokenErrorMessage ?? 'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu liên kết mới.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        ElevatedButton(
          onPressed: _showForgotPasswordSheet,
          child: const Text('Yêu cầu gửi lại email'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            _authNotifier.cancelResetPassword();
            context.go('/login');
          },
          child: const Text('Quay lại trang đăng nhập'),
        ),
      ],
    );
  }

  Widget _buildFormState(AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Emblem / Header
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: AppColors.onPrimary,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Đặt lại mật khẩu',
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo mật khẩu mới cho tài khoản ca viên của bạn',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Server Error banner
          if (authState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.6),
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

          // New Password Field
          Text('Mật khẩu mới', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _isNewPasswordObscured,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Nhập mật khẩu mới',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _isNewPasswordObscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () {
                  setState(() {
                    _isNewPasswordObscured = !_isNewPasswordObscured;
                  });
                },
              ),
            ),
            validator: _validateNewPassword,
            onChanged: (_) {
              if (authState.errorMessage != null) {
                ref.read(authNotifierProvider.notifier).clearErrors();
              }
            },
          ),
          const SizedBox(height: 8),

          // Policy hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Tối thiểu 8 ký tự, bao gồm cả chữ cái và số.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Confirm Password Field
          Text('Xác nhận mật khẩu mới', style: AppTypography.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _isConfirmPasswordObscured,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitResetPassword(),
            decoration: InputDecoration(
              hintText: 'Nhập lại mật khẩu mới',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordObscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordObscured = !_isConfirmPasswordObscured;
                  });
                },
              ),
            ),
            validator: _validateConfirmPassword,
            onChanged: (_) {
              if (authState.errorMessage != null) {
                ref.read(authNotifierProvider.notifier).clearErrors();
              }
            },
          ),
          const SizedBox(height: 28),

          // Submit Button
          ElevatedButton(
            onPressed: authState.isLoading ? null : _submitResetPassword,
            child: authState.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                : const Text('Đặt lại mật khẩu'),
          ),
          const SizedBox(height: 16),

          // Alternative action: back to login
          TextButton(
            onPressed: () {
              _authNotifier.cancelResetPassword();
              context.go('/login');
            },
            child: Text(
              'Quay lại trang đăng nhập',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
