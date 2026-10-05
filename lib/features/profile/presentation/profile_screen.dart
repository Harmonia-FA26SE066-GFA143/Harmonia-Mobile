import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Key _profileRefreshKey = UniqueKey();

  void _refreshProfile() {
    ref.invalidate(currentMemberProfileProvider);
    setState(() {
      _profileRefreshKey = UniqueKey();
    });
  }

  void _showEditProfileDialog(
    BuildContext context,
    ProfileRepository repo,
    MemberProfileDto profile,
  ) {
    final nameController = TextEditingController(text: profile.fullName);
    final phoneController = TextEditingController(text: profile.phone ?? '');
    final dobController = TextEditingController(
      text: profile.dateOfBirth ?? '',
    );
    bool isSaving = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cập nhật hồ sơ ca viên',
                          style: AppTypography.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Họ và tên', style: AppTypography.labelLarge),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'Nhập họ và tên...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Số điện thoại', style: AppTypography.labelLarge),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'VD: 0912345678',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Ngày sinh', style: AppTypography.labelLarge),
                    const SizedBox(height: 6),
                    TextField(
                      controller: dobController,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        hintText: 'YYYY-MM-DD (VD: 1995-05-15)',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.statusDanger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                setModalState(() {
                                  errorMessage =
                                      'Họ và tên không được để trống.';
                                });
                                return;
                              }

                              setModalState(() {
                                isSaving = true;
                                errorMessage = null;
                              });

                              try {
                                final nav = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(
                                  this.context,
                                );
                                final phone = phoneController.text.trim();
                                final dob = dobController.text.trim();
                                await repo.updateProfile(
                                  UpdateMyMemberProfileRequest(
                                    fullName: name,
                                    phone: phone.isNotEmpty ? phone : null,
                                    dateOfBirth: dob.isNotEmpty ? dob : null,
                                  ),
                                );
                                if (mounted) {
                                  nav.pop();
                                  _refreshProfile();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Đã cập nhật hồ sơ thành công!',
                                      ),
                                      backgroundColor: AppColors.statusSuccess,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isSaving = false;
                                  errorMessage = 'Không thể cập nhật hồ sơ. Vui lòng kiểm tra lại.';
                                });
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Lưu thay đổi'),
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

  void _showChangePasswordDialog(BuildContext context) {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();
    bool isSaving = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Đổi mật khẩu', style: AppTypography.titleLarge),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Mật khẩu hiện tại', style: AppTypography.labelLarge),
                    const SizedBox(height: 6),
                    TextField(
                      controller: currentPwController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Nhập mật khẩu đang dùng',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Mật khẩu mới', style: AppTypography.labelLarge),
                    const SizedBox(height: 6),
                    TextField(
                      controller: newPwController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Tối thiểu 6 ký tự',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Xác nhận mật khẩu mới',
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmPwController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'Nhập lại mật khẩu mới',
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.statusDanger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final currentPw = currentPwController.text;
                              final newPw = newPwController.text;
                              final confirmPw = confirmPwController.text;

                              if (currentPw.isEmpty || newPw.isEmpty) {
                                setModalState(() {
                                  errorMessage =
                                      'Vui lòng nhập đầy đủ thông tin.';
                                });
                                return;
                              }
                              if (newPw != confirmPw) {
                                setModalState(() {
                                  errorMessage =
                                      'Xác nhận mật khẩu mới không khớp.';
                                });
                                return;
                              }

                              setModalState(() {
                                isSaving = true;
                                errorMessage = null;
                              });

                              final nav = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(
                                this.context,
                              );
                              final ok = await ref
                                  .read(authNotifierProvider.notifier)
                                  .changePassword(
                                    currentPassword: currentPw,
                                    newPassword: newPw,
                                  );

                              if (ok && mounted) {
                                nav.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã đổi mật khẩu thành công!',
                                    ),
                                    backgroundColor: AppColors.statusSuccess,
                                  ),
                                );
                              } else {
                                setModalState(() {
                                  isSaving = false;
                                  errorMessage =
                                      ref
                                          .read(authNotifierProvider)
                                          .errorMessage ??
                                      'Không thể đổi mật khẩu. Vui lòng kiểm tra lại.';
                                });
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Text('Đổi mật khẩu'),
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text(
            'Bạn có chắc chắn muốn kết thúc phiên đăng nhập trên thiết bị này?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusDanger,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final nav = Navigator.of(context);
                final router = GoRouter.of(this.context);
                nav.pop();
                await ref.read(authNotifierProvider.notifier).logout();
                if (mounted) {
                  router.go('/login');
                }
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(profileRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Hồ sơ cá nhân', style: AppTypography.headlineSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _refreshProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<MemberProfileDto>(
          key: _profileRefreshKey,
          future: repo.getProfile(),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (profileSnap.hasError || !profileSnap.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.statusDanger,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Không thể tải dữ liệu hồ sơ từ máy chủ.',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshProfile,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final profile = profileSnap.data!;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Header Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                profile.fullName.isNotEmpty
                                    ? profile.fullName[0].toUpperCase()
                                    : 'C',
                                style: AppTypography.headlineMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.fullName,
                                  style: AppTypography.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Ca viên • ${profile.status.label}',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.email,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Detail Information Card (Real data from /member-profiles/me)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Thông tin cá nhân',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _showEditProfileDialog(
                                  context,
                                  repo,
                                  profile,
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Chỉnh sửa'),
                              ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            Icons.person_outline_rounded,
                            'Họ và tên',
                            profile.fullName,
                          ),
                          _buildInfoRow(
                            Icons.email_outlined,
                            'Email',
                            profile.email,
                          ),
                          _buildInfoRow(
                            Icons.phone_outlined,
                            'Số điện thoại',
                            profile.phone != null && profile.phone!.isNotEmpty
                                ? profile.phone!
                                : 'Chưa cập nhật',
                          ),
                          _buildInfoRow(
                            Icons.cake_outlined,
                            'Ngày sinh',
                            profile.dateOfBirth != null &&
                                    profile.dateOfBirth!.isNotEmpty
                                ? profile.dateOfBirth!
                                : 'Chưa cập nhật',
                          ),
                          _buildInfoRow(
                            Icons.calendar_month_outlined,
                            'Ngày tham gia',
                            profile.joinedDate.isNotEmpty
                                ? profile.joinedDate
                                : 'Chưa có thông tin',
                          ),
                          _buildInfoRow(
                            Icons.check_circle_outline_rounded,
                            'Trạng thái hoạt động',
                            profile.status.label,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Security & Actions Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.lock_reset_rounded,
                              color: AppColors.primary,
                            ),
                            title: const Text('Đổi mật khẩu'),
                            subtitle: const Text(
                              'Cập nhật mật khẩu đăng nhập Harmonia',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _showChangePasswordDialog(context),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.logout_rounded,
                              color: AppColors.statusDanger,
                            ),
                            title: const Text(
                              'Đăng xuất',
                              style: TextStyle(color: AppColors.statusDanger),
                            ),
                            subtitle: const Text(
                              'Kết thúc phiên làm việc trên thiết bị',
                            ),
                            onTap: () => _showLogoutDialog(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
