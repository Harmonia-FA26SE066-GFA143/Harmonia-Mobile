import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import 'auth_notifier.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  final bool isForced;

  const ChangePasswordScreen({super.key, this.isForced = false});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _localError;
  bool _isSuccess = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final currentPw = _currentPasswordController.text;
    final newPw = _newPasswordController.text;
    final confirmPw = _confirmPasswordController.text;

    if (currentPw.isEmpty) {
      setState(() => _localError = 'Vui lòng nhập mật khẩu hiện tại.');
      return;
    }
    if (newPw.length < 8) {
      setState(() => _localError = 'Mật khẩu mới phải có ít nhất 8 ký tự.');
      return;
    }
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(newPw);
    final hasDigit = RegExp(r'[0-9]').hasMatch(newPw);
    if (!hasLetter || !hasDigit) {
      setState(() => _localError = 'Mật khẩu phải bao gồm cả chữ và số.');
      return;
    }
    if (newPw == currentPw) {
      setState(
        () => _localError =
            'Mật khẩu mới không được trùng với mật khẩu hiện tại.',
      );
      return;
    }
    if (newPw != confirmPw) {
      setState(() => _localError = 'Mật khẩu xác nhận không khớp.');
      return;
    }

    setState(() => _localError = null);

    final success = await ref
        .read(authNotifierProvider.notifier)
        .changePassword(currentPassword: currentPw, newPassword: newPw);

    if (!mounted) return;

    if (success) {
      setState(() => _isSuccess = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đổi mật khẩu thành công. Vui lòng đăng nhập lại với mật khẩu mới.',
          ),
          backgroundColor: AppColors.statusSuccess,
          duration: Duration(seconds: 4),
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final errorMessage = _localError ?? authState.errorMessage;

    return PopScope(
      canPop: !widget.isForced,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            widget.isForced ? 'Bắt buộc đổi mật khẩu' : 'Đổi mật khẩu',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          automaticallyImplyLeading: !widget.isForced,
          centerTitle: true,
          actions: [
            if (widget.isForced)
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Đăng xuất',
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                },
              ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isForced) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.statusWarningSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.statusWarning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_reset_rounded,
                          color: AppColors.statusWarning,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tài khoản của bạn yêu cầu đổi mật khẩu lần đầu trước khi truy cập ứng dụng Harmonia.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.body,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (errorMessage != null && !_isSuccess) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusDangerSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.statusDanger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.statusDanger,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.statusDanger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Text('Mật khẩu hiện tại', style: AppTypography.labelLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    hintText: 'Nhập mật khẩu hiện tại',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Mật khẩu mới', style: AppTypography.labelLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    hintText: 'Tối thiểu 8 ký tự, gồm cả chữ và số',
                    prefixIcon: const Icon(Icons.lock_clock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Xác nhận mật khẩu mới', style: AppTypography.labelLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: 'Nhập lại mật khẩu mới',
                    prefixIcon: const Icon(Icons.check_circle_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Xác nhận đổi mật khẩu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
