import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _showDeclareSkillDialog(BuildContext context, ProfileRepository repo) {
    final nameController = TextEditingController();
    final noteController = TextEditingController();
    String selectedCategory = 'Kỹ năng thanh nhạc';
    String selectedLevel = 'Trung cấp';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Khai báo kỹ năng mới',
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thông tin sẽ được gửi đến Ca trưởng để đánh giá và phê duyệt.',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 18),

                    // Tên kỹ năng
                    Text('Tên kỹ năng', style: AppTypography.labelLarge),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        hintText: 'VD: Thị tấu, Đệm đàn Organ, Hát đơn ca...',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nhóm kỹ năng
                    Text('Nhóm kỹ năng', style: AppTypography.labelLarge),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: 'Kỹ năng thanh nhạc',
                          child: Text('Kỹ năng thanh nhạc'),
                        ),
                        DropdownMenuItem(
                          value: 'Kỹ năng nhạc cụ',
                          child: Text('Kỹ năng nhạc cụ'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Trình độ tự đánh giá
                    Text(
                      'Trình độ tự đánh giá',
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedLevel,
                      decoration: const InputDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: 'Sơ cấp',
                          child: Text('Sơ cấp'),
                        ),
                        DropdownMenuItem(
                          value: 'Trung cấp',
                          child: Text('Trung cấp'),
                        ),
                        DropdownMenuItem(
                          value: 'Nâng cao',
                          child: Text('Nâng cao'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedLevel = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Ghi chú
                    Text(
                      'Ghi chú / Chứng chỉ liên quan',
                      style: AppTypography.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Nêu quá trình học tập hoặc kinh nghiệm...',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isEmpty) return;

                        await repo.declareNewSkill(
                          name: nameController.text.trim(),
                          categoryName: selectedCategory,
                          level: selectedLevel,
                          note: noteController.text.trim(),
                        );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã gửi khai báo kỹ năng đến Ca trưởng.',
                              ),
                              backgroundColor: AppColors.statusSuccess,
                            ),
                          );
                        }
                      },
                      child: const Text('Gửi khai báo'),
                    ),
                    const SizedBox(height: 24),
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
          title: Text('Đăng xuất tài khoản', style: AppTypography.titleLarge),
          content: Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng Harmonia Mobile?',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(110, 44),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
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
        title: Text('Cá nhân & Kỹ năng', style: AppTypography.headlineSmall),
      ),
      body: SafeArea(
        child: FutureBuilder<MemberProfile>(
          future: repo.getProfile(),
          builder: (context, profileSnap) {
            final profile = profileSnap.data;
            if (profile == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

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
                                profile.saintName.isNotEmpty
                                    ? profile.saintName[0]
                                    : 'M',
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
                                Text(
                                  profile.voicePart,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.email,
                                  style: AppTypography.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Text(
                                  '${profile.attendancePercentage}%',
                                  style: AppTypography.headlineMedium.copyWith(
                                    color: AppColors.statusSuccess,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tỉ lệ tham gia',
                                  style: AppTypography.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Text(
                                  '${profile.totalServicesCount}',
                                  style: AppTypography.headlineMedium.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Buổi phục vụ',
                                  style: AppTypography.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section Skills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kỹ năng của tôi',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showDeclareSkillDialog(context, repo),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Khai báo thêm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  FutureBuilder<List<MemberSkill>>(
                    future: repo.getSkills(),
                    builder: (context, skillsSnap) {
                      final skills = skillsSnap.data ?? [];
                      if (skills.isEmpty) {
                        return const Center(
                          child: Text('Chưa khai báo kỹ năng nào'),
                        );
                      }

                      return Column(
                        children: skills.map((skill) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  color: AppColors.secondary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                skill.name,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${skill.categoryName} • ${skill.level}',
                                style: AppTypography.bodySmall,
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      skill.status ==
                                          SkillApprovalStatus.approved
                                      ? AppColors.statusSuccessSoft
                                      : AppColors.statusWarningSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  skill.status.label,
                                  style: AppTypography.labelSmall.copyWith(
                                    color:
                                        skill.status ==
                                            SkillApprovalStatus.approved
                                        ? AppColors.statusSuccess
                                        : AppColors.statusWarning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Logout Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Đăng xuất tài khoản'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
