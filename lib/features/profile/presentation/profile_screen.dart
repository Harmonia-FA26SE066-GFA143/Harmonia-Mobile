import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../../auth/data/auth_dto.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../lookups/data/lookup_dto.dart';
import '../../lookups/data/lookups_api_service.dart';
import '../data/avatar_image_picker.dart';
import '../data/member_skill_evidence_picker.dart';
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Key _profileRefreshKey = UniqueKey();
  bool _logoutDialogOpen = false;
  bool _isAvatarUpdating = false;
  late final AppLifecycleListener _lifecycleListener;

  Future<void> _deleteTemporaryEvidence(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // The operating system may already have removed the temporary file.
    }
  }

  Future<void> _reloadAvatar() async {
    ref.invalidate(currentMemberProfileProvider);
    setState(() => _profileRefreshKey = UniqueKey());
  }

  String _avatarErrorMessage(Object error) {
    if (error is AppException) {
      return switch (error.code) {
        'AVATAR_FILE_TOO_LARGE' => 'Ảnh đại diện không được vượt quá 2 MB.',
        'AVATAR_FILE_TYPE_NOT_ALLOWED' => 'Chỉ hỗ trợ ảnh JPG, PNG hoặc WEBP.',
        'AVATAR_FILE_REQUIRED' => 'Không tìm thấy tệp ảnh đã chọn.',
        'EXTERNAL_STORAGE_FAILED' =>
          'Máy chủ chưa lưu được ảnh. Vui lòng thử lại sau.',
        _ => error.message,
      };
    }
    if (error is PlatformException) {
      return switch (error.code) {
        'AVATAR_FILE_TOO_LARGE' => 'Ảnh đại diện không được vượt quá 2 MB.',
        'AVATAR_FILE_TYPE_NOT_ALLOWED' => 'Chỉ hỗ trợ ảnh JPG, PNG hoặc WEBP.',
        _ => 'Không thể mở thư viện ảnh. Vui lòng thử lại.',
      };
    }
    return 'Không thể cập nhật ảnh đại diện. Vui lòng thử lại.';
  }

  Future<void> _pickAndUploadAvatar(ProfileRepository repo) async {
    if (_isAvatarUpdating) return;
    setState(() => _isAvatarUpdating = true);
    String? selectedPath;
    try {
      selectedPath = await AvatarImagePicker().pickImage();
      if (!mounted || selectedPath == null) return;
      await repo.updateAvatar(selectedPath);
      if (!mounted) return;
      await _reloadAvatar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật ảnh đại diện.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_avatarErrorMessage(error))));
    } finally {
      if (selectedPath != null) {
        try {
          final file = File(selectedPath);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _isAvatarUpdating = false);
    }
  }

  Future<void> _deleteAvatar(ProfileRepository repo) async {
    if (_isAvatarUpdating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa ảnh đại diện?'),
        content: const Text('Bạn có thể thêm ảnh mới bất cứ lúc nào.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa ảnh'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _isAvatarUpdating = true);
    try {
      await repo.deleteAvatar();
      if (!mounted) return;
      await _reloadAvatar();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã xóa ảnh đại diện.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_avatarErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isAvatarUpdating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!ref.read(sessionManagerProvider).isAuthenticated) return;
        unawaited(ref.read(signalRServiceProvider).connect());
        unawaited(ref.read(memberSkillsNotifierProvider.notifier).refresh());
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    final synced = await ref
        .read(authNotifierProvider.notifier)
        .synchronizeAccount();
    if (!mounted || !ref.read(sessionManagerProvider).isAuthenticated) return;
    if (!synced) {
      final message = ref.read(authNotifierProvider).errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
    ref.invalidate(currentMemberProfileProvider);
    ref.invalidate(currentMemberSkillsProvider);
    ref.read(memberSkillsNotifierProvider.notifier).refresh();
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
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 8,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Cập nhật hồ sơ ca viên',
                            style: AppTypography.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Họ và tên *', style: AppTypography.labelLarge),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF842539),
                      ),
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

                                // Update profile via MemberProfiles
                                await repo.updateProfile(
                                  UpdateMyMemberProfileRequest(
                                    fullName: name,
                                    phone: phone.isNotEmpty
                                        ? phone
                                        : profile.phone,
                                    dateOfBirth: dob.isNotEmpty
                                        ? dob
                                        : profile.dateOfBirth,
                                  ),
                                );

                                // Also sync UserDto via /api/auth/me to avoid losing phone
                                try {
                                  await ref
                                      .read(authRepositoryProvider)
                                      .updateMe(
                                        UpdateMyUserRequest(
                                          fullName: name,
                                          phone: phone.isNotEmpty
                                              ? phone
                                              : profile.phone,
                                        ),
                                      );
                                } catch (_) {}

                                if (mounted) {
                                  nav.pop();
                                  _refreshProfile();
                                  messenger.showSnackBar(
                                    SnackBar(
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
                                  errorMessage = 'Không thể cập nhật hồ sơ: $e';
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

  void _showDeclareSkillDialog(BuildContext context, ProfileRepository repo) {
    SkillDto? selectedSkill;
    SkillLevel selectedLevel = SkillLevel.intermediate;
    String? evidencePath;
    String? evidenceFileName;

    bool isSubmitting = false;
    String? errorMessage;
    final skillsRequest = ref.read(lookupsApiServiceProvider).getSkills();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return FutureBuilder<List<SkillDto>>(
          future: skillsRequest,
          builder: (context, snapshot) => StatefulBuilder(
            builder: (context, setModalState) {
              final isLoadingSkills =
                  snapshot.connectionState != ConnectionState.done;
              final availableSkills = snapshot.data ?? const <SkillDto>[];
              selectedSkill ??= availableSkills.firstOrNull;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 20,
                  right: 20,
                  top: 8,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Khai báo kỹ năng mới',
                              style: AppTypography.headlineSmall.copyWith(
                                fontFamily: 'Playfair Display',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bản khai sẽ được gửi tới Ca trưởng xem xét và phê duyệt.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Chọn kỹ năng *', style: AppTypography.labelLarge),
                      const SizedBox(height: 6),
                      if (isLoadingSkills)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      else if (availableSkills.isEmpty)
                        Text(
                          snapshot.hasError
                              ? ErrorMessages.forException(
                                  snapshot.error,
                                  defaultMessage:
                                      'Không thể tải danh sách kỹ năng.',
                                )
                              : 'Không có danh mục kỹ năng khả dụng',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.statusDanger,
                          ),
                        )
                      else
                        DropdownButtonFormField<SkillDto>(
                          initialValue: selectedSkill,
                          isExpanded: true,
                          decoration: InputDecoration(
                            fillColor: const Color(0xFFF0F3FF),
                            prefixIcon: const Icon(Icons.music_note_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          items: availableSkills
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setModalState(() => selectedSkill = val);
                          },
                        ),
                      const SizedBox(height: 14),
                      Text('Cấp độ năng lực', style: AppTypography.labelLarge),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<SkillLevel>(
                        initialValue: selectedLevel,
                        isExpanded: true,
                        decoration: InputDecoration(
                          fillColor: const Color(0xFFF0F3FF),
                          prefixIcon: const Icon(
                            Icons.workspace_premium_outlined,
                            color: AppColors.statusWarning,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: SkillLevel.values
                            .map(
                              (l) => DropdownMenuItem(
                                value: l,
                                child: Text(l.label),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedLevel = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Minh chứng ghi âm hoặc video (không bắt buộc)',
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF6F8),
                          side: const BorderSide(color: Color(0xFFFFBACB)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                try {
                                  final path = await MemberSkillEvidencePicker()
                                      .pickFile();
                                  if (path == null || !context.mounted) return;
                                  final previousPath = evidencePath;
                                  setModalState(() {
                                    evidencePath = path;
                                    evidenceFileName = File(path)
                                        .uri
                                        .pathSegments
                                        .last;
                                    errorMessage = null;
                                  });
                                  if (previousPath != null) {
                                    unawaited(
                                      _deleteTemporaryEvidence(previousPath),
                                    );
                                  }
                                } catch (error) {
                                  if (!context.mounted) return;
                                  setModalState(() {
                                    errorMessage = ErrorMessages.forException(
                                      error,
                                      defaultMessage:
                                          'Không thể mở thư viện tệp.',
                                    );
                                  });
                                }
                              },
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(
                          evidenceFileName == null
                              ? 'Chọn ghi âm hoặc video'
                              : 'Đổi tệp minh chứng',
                        ),
                      ),
                      if (evidenceFileName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.attach_file_rounded,
                                size: 16,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  evidenceFileName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Bỏ tệp minh chứng',
                                visualDensity: VisualDensity.compact,
                                onPressed: isSubmitting
                                    ? null
                                    : () {
                                        final previousPath = evidencePath;
                                        setModalState(() {
                                          evidencePath = null;
                                          evidenceFileName = null;
                                        });
                                        if (previousPath != null) {
                                          unawaited(
                                            _deleteTemporaryEvidence(
                                              previousPath,
                                            ),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        'Ghi âm MP3, M4A, WAV tối đa 20 MB; video MP4, MOV tối đa 100 MB.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.muted,
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
                        onPressed: isSubmitting || selectedSkill == null
                            ? null
                            : () async {
                                setModalState(() {
                                  isSubmitting = true;
                                  errorMessage = null;
                                });

                                try {
                                  final nav = Navigator.of(context);
                                  final messenger = ScaffoldMessenger.of(
                                    this.context,
                                  );
                                  // Send actual skillId GUID and English enum wireName
                                  final declaredSkill = await repo
                                      .declareNewSkill(
                                        skillId: selectedSkill!.id,
                                        level: selectedLevel.wireName,
                                        name: selectedSkill!.name,
                                      );

                                  if (evidencePath != null) {
                                    try {
                                      await repo.uploadSkillEvidence(
                                        id: declaredSkill.id,
                                        filePath: evidencePath!,
                                      );
                                    } catch (error) {
                                      nav.pop();
                                      await _deleteTemporaryEvidence(
                                        evidencePath!,
                                      );
                                      if (mounted) {
                                        ref.invalidate(
                                          currentMemberSkillsProvider,
                                        );
                                        ref
                                            .read(
                                              memberSkillsNotifierProvider
                                                  .notifier,
                                            )
                                            .refresh();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Bản khai đã gửi, nhưng minh chứng chưa tải lên: ${ErrorMessages.forException(error)}. Mở kỹ năng vừa khai báo để thử gửi lại.',
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                  }

                                  if (mounted) {
                                    nav.pop();
                                    if (evidencePath != null) {
                                      await _deleteTemporaryEvidence(
                                        evidencePath!,
                                      );
                                    }
                                    ref.invalidate(currentMemberSkillsProvider);
                                    ref
                                        .read(
                                          memberSkillsNotifierProvider.notifier,
                                        )
                                        .refresh();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          evidencePath == null
                                              ? 'Đã gửi bản khai kỹ năng thành công! Đang chờ duyệt.'
                                              : 'Đã gửi bản khai và minh chứng thành công. Đang chờ duyệt.',
                                        ),
                                        backgroundColor:
                                            AppColors.statusSuccess,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    errorMessage =
                                        'Không thể gửi bản khai: ${ErrorMessages.forException(e)}';
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
                            : const Text('Gửi bản khai kỹ năng'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      final path = evidencePath;
      if (path != null) unawaited(_deleteTemporaryEvidence(path));
    });
  }

  void _showSkillDetailDialog(BuildContext context, String skillId) {
    var isUploadingEvidence = false;
    double? evidenceUploadProgress;
    String? evidenceUploadError;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            return StatefulBuilder(
              builder: (context, setSheetState) => FutureBuilder<MemberSkill?>(
                future: ref.watch(memberSkillDetailProvider(skillId).future),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: AppColors.statusDanger,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Không thể tải chi tiết kỹ năng: ${snapshot.error}',
                            style: AppTypography.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Đóng'),
                          ),
                        ],
                      ),
                    );
                  }

                  final skill = snapshot.data;
                  if (skill == null) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Không tìm thấy thông tin kỹ năng.'),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Đóng'),
                          ),
                        ],
                      ),
                    );
                  }

                  Color badgeBg;
                  Color badgeFg;
                  if (skill.status == SkillApprovalStatus.approved) {
                    badgeBg = AppColors.statusSuccessSoft;
                    badgeFg = AppColors.statusSuccess;
                  } else if (skill.status == SkillApprovalStatus.rejected) {
                    badgeBg = AppColors.statusDangerSoft;
                    badgeFg = AppColors.statusDanger;
                  } else {
                    badgeBg = AppColors.statusWarningSoft;
                    badgeFg = AppColors.statusWarning;
                  }

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Chi tiết kỹ năng',
                              style: AppTypography.titleLarge,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          skill.name,
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          skill.categoryName,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                skill.status.label,
                                style: AppTypography.labelSmall.copyWith(
                                  color: badgeFg,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                'Cấp độ: ${skill.levelLabel}',
                                style: AppTypography.labelSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (skill.declaredAt != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Ngày khai báo: ${DateFormat('dd/MM/yyyy HH:mm').format(skill.declaredAt!)}',
                              style: AppTypography.bodySmall,
                            ),
                          ),
                        if (skill.approvedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Ngày duyệt: ${DateFormat('dd/MM/yyyy HH:mm').format(skill.approvedAt!)}',
                              style: AppTypography.bodySmall,
                            ),
                          ),
                        if (skill.status == SkillApprovalStatus.rejected &&
                            skill.rejectReason != null &&
                            skill.rejectReason!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.statusDangerSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lý do từ chối từ Ca trưởng:',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.statusDanger,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  skill.rejectReason!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.statusDanger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (skill.evidence != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  skill.evidence!.type == 'Voice'
                                      ? Icons.mic_none_rounded
                                      : Icons.videocam_outlined,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        skill.evidence!.fileName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.labelLarge,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${skill.evidence!.type == 'Voice' ? 'Ghi âm' : 'Video'} • ${(skill.evidence!.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (skill.status == SkillApprovalStatus.pending) ...[
                          if (evidenceUploadError != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              evidenceUploadError!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.statusDanger,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: isUploadingEvidence
                                ? null
                                : () async {
                                    String? path;
                                    try {
                                      path = await MemberSkillEvidencePicker()
                                          .pickFile();
                                    } catch (error) {
                                      if (!context.mounted) return;
                                      setSheetState(() {
                                        evidenceUploadError =
                                            ErrorMessages.forException(
                                              error,
                                              defaultMessage:
                                                  'Không thể mở thư viện tệp.',
                                            );
                                      });
                                      return;
                                    }
                                    if (path == null || !context.mounted) {
                                      return;
                                    }
                                    setSheetState(() {
                                      isUploadingEvidence = true;
                                      evidenceUploadProgress = 0;
                                      evidenceUploadError = null;
                                    });
                                    try {
                                      await ref
                                          .read(profileRepositoryProvider)
                                          .uploadSkillEvidence(
                                            id: skill.id,
                                            filePath: path,
                                            onSendProgress: (sent, total) {
                                              if (total > 0 &&
                                                  context.mounted) {
                                                setSheetState(() {
                                                  evidenceUploadProgress =
                                                      sent / total;
                                                });
                                              }
                                            },
                                          );
                                      if (!context.mounted) return;
                                      setSheetState(() {
                                        isUploadingEvidence = false;
                                        evidenceUploadProgress = null;
                                      });
                                      ref.invalidate(
                                        memberSkillDetailProvider(skill.id),
                                      );
                                      await ref
                                          .read(
                                            memberSkillsNotifierProvider
                                                .notifier,
                                          )
                                          .refresh();
                                      if (mounted) {
                                        ScaffoldMessenger.of(this.context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Đã gửi minh chứng cho Ca trưởng.',
                                                ),
                                              ),
                                            );
                                      }
                                    } catch (error) {
                                      if (!context.mounted) return;
                                      setSheetState(() {
                                        isUploadingEvidence = false;
                                        evidenceUploadProgress = null;
                                        evidenceUploadError =
                                            ErrorMessages.forException(
                                              error,
                                              defaultMessage: 'Không thể tải minh chứng lên. Vui lòng thử lại.',
                                            );
                                      });
                                    } finally {
                                      try {
                                        await File(path).delete();
                                      } on FileSystemException {
                                        // The operating system may already have removed the temporary file.
                                      }
                                    }
                                  },
                            icon: isUploadingEvidence
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.upload_file_rounded),
                            label: Text(
                              isUploadingEvidence
                                  ? 'Đang tải ${(100 * (evidenceUploadProgress ?? 0)).round()}%'
                                  : skill.evidence == null
                                  ? 'Gửi minh chứng ghi âm / video'
                                  : 'Thay minh chứng',
                            ),
                          ),
                          if (isUploadingEvidence &&
                              evidenceUploadProgress != null) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: evidenceUploadProgress,
                              color: AppColors.primary,
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Ghi âm tối đa 20 MB; video tối đa 100 MB. Chỉ có thể gửi khi kỹ năng đang chờ duyệt.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    if (_logoutDialogOpen || ref.read(authNotifierProvider).isLoading) return;
    _logoutDialogOpen = true;
    final session = ref.read(sessionManagerProvider);
    final epoch = session.sessionEpoch;
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất'),
          content: const Text(
            'Bạn có chắc chắn muốn kết thúc phiên đăng nhập trên thiết bị này?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusDanger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
    _logoutDialogOpen = false;
    if (!mounted || confirmed != true || session.sessionEpoch != epoch) return;
    final notifier = ref.read(authNotifierProvider.notifier);
    await notifier.logout();
    if (session.isAuthenticated || session.sessionEpoch != epoch + 1) return;
    router.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(profileRepositoryProvider);
    final skillsState = ref.watch(memberSkillsNotifierProvider);
    final profileFuture = ref.watch(currentMemberProfileProvider.future);

    return FutureBuilder<MemberProfileDto>(
      key: _profileRefreshKey,
      future: profileFuture,
      builder: (context, profileSnap) {
        final avatarProfile = profileSnap.data;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            toolbarHeight: 80,
            backgroundColor: AppColors.surface,
            title: Text('Hồ sơ ca viên', style: AppTypography.headlineMedium),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton.filledTonal(
                  tooltip: 'Ảnh đại diện',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: Color(0xFFFFA5BA)),
                  ),
                  onPressed: avatarProfile == null || _isAvatarUpdating
                      ? null
                      : () => _showAvatarActions(repo, avatarProfile),
                  icon: _isAvatarUpdating
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_outline_rounded),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: FutureBuilder<MemberProfileDto>(
              key: _profileRefreshKey,
              future: profileFuture,
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
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _refreshProfile,
                            child: const Text('Thử lại'),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final busy = ref.watch(
                                authNotifierProvider.select(
                                  (auth) => auth.isLoading,
                                ),
                              );
                              return TextButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _showLogoutDialog(context),
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Đăng xuất'),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final profile = profileSnap.data!;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Detail Information Card
                      StitchEntrance(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Thông tin cá nhân',
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        backgroundColor: AppColors.primarySoft,
                                      ),
                                      onPressed: () => _showEditProfileDialog(
                                        context,
                                        repo,
                                        profile,
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                      ),
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
                                  profile.phone != null &&
                                          profile.phone!.isNotEmpty
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
                      ),
                      const SizedBox(height: 16),

                      // Member Skills Section (UC-03)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Kỹ năng của tôi (${skillsState.totalCount > 0 ? skillsState.totalCount : skillsState.items.length})',
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        _showDeclareSkillDialog(context, repo),
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Khai báo'),
                                  ),
                                ],
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              if (skillsState.isLoading &&
                                  skillsState.items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              else if (skillsState.errorMessage != null &&
                                  skillsState.items.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          skillsState.errorMessage!,
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                color: AppColors.statusDanger,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: () => ref
                                              .read(
                                                memberSkillsNotifierProvider
                                                    .notifier,
                                              )
                                              .loadInitial(),
                                          child: const Text('Thử lại'),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (skillsState.items.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Bạn chưa khai báo kỹ năng nào.',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: skillsState.items.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 12),
                                  itemBuilder: (context, index) {
                                    final skill = skillsState.items[index];
                                    Color badgeBg;
                                    Color badgeFg;
                                    if (skill.status ==
                                        SkillApprovalStatus.approved) {
                                      badgeBg = AppColors.statusSuccessSoft;
                                      badgeFg = AppColors.statusSuccess;
                                    } else if (skill.status ==
                                        SkillApprovalStatus.rejected) {
                                      badgeBg = AppColors.statusDangerSoft;
                                      badgeFg = AppColors.statusDanger;
                                    } else {
                                      badgeBg = AppColors.statusWarningSoft;
                                      badgeFg = AppColors.statusWarning;
                                    }

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showSkillDetailDialog(
                                        context,
                                        skill.id,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                          horizontal: 4,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        skill.name,
                                                        style: AppTypography
                                                            .titleMedium
                                                            .copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${skill.categoryName} • Cấp độ: ${skill.levelLabel}',
                                                        style: AppTypography
                                                            .bodySmall
                                                            .copyWith(
                                                              color: AppColors
                                                                  .muted,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: badgeBg,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          24,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    skill.status.label,
                                                    style: AppTypography
                                                        .labelSmall
                                                        .copyWith(
                                                          color: badgeFg,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (skill.status ==
                                                    SkillApprovalStatus
                                                        .rejected &&
                                                (skill.rejectReason != null &&
                                                    skill
                                                        .rejectReason!
                                                        .isNotEmpty)) ...[
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors
                                                      .statusDangerSoft,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .info_outline_rounded,
                                                      size: 16,
                                                      color: AppColors
                                                          .statusDanger,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Lý do từ chối: ${skill.rejectReason!}',
                                                        style: AppTypography
                                                            .bodySmall
                                                            .copyWith(
                                                              color: AppColors
                                                                  .statusDanger,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (skillsState.hasNextPage) ...[
                                  const SizedBox(height: 12),
                                  if (skillsState.isLoadingMore)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  else if (skillsState.loadMoreErrorMessage !=
                                      null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              skillsState.loadMoreErrorMessage!,
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                    color:
                                                        AppColors.statusDanger,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: () => ref
                                                .read(
                                                  memberSkillsNotifierProvider
                                                      .notifier,
                                                )
                                                .loadMore(),
                                            child: const Text('Thử lại'),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Center(
                                      child: OutlinedButton.icon(
                                        onPressed: () => ref
                                            .read(
                                              memberSkillsNotifierProvider
                                                  .notifier,
                                            )
                                            .loadMore(),
                                        icon: const Icon(
                                          Icons.arrow_downward_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Tải thêm kỹ năng'),
                                      ),
                                    ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Activities & History Card (UC-11)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.history_rounded,
                                  color: AppColors.primary,
                                ),
                                title: const Text(
                                  'Lịch sử tham gia & luyện tập',
                                ),
                                subtitle: const Text(
                                  'Xem kết quả phục vụ lễ và bài tập đã hoàn thành',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => context.push('/profile/history'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Security & Actions Card
                      Consumer(
                        builder: (context, ref, _) {
                          final busy = ref.watch(
                            authNotifierProvider.select(
                              (auth) => auth.isLoading,
                            ),
                          );
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  ListTile(
                                    enabled: !busy,
                                    leading: const Icon(
                                      Icons.lock_reset_rounded,
                                      color: AppColors.primary,
                                    ),
                                    title: const Text('Đổi mật khẩu'),
                                    subtitle: const Text(
                                      'Cập nhật mật khẩu đăng nhập Harmonia',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onTap: () =>
                                        context.push('/change-password'),
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    enabled: !busy,
                                    leading: const Icon(
                                      Icons.logout_rounded,
                                      color: AppColors.statusDanger,
                                    ),
                                    title: const Text(
                                      'Đăng xuất',
                                      style: TextStyle(
                                        color: AppColors.statusDanger,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Kết thúc phiên làm việc trên thiết bị',
                                    ),
                                    onTap: () => _showLogoutDialog(context),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showAvatarActions(ProfileRepository repo, MemberProfileDto profile) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ảnh đại diện',
                      style: AppTypography.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: profile.avatarUrl?.isNotEmpty == true
                                ? Image.network(
                                    profile.avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      Icons.person_outline_rounded,
                                      color: AppColors.primary,
                                      size: 42,
                                    ),
                                  )
                                : Icon(
                                    Icons.person_outline_rounded,
                                    color: AppColors.primary,
                                    size: 42,
                                  ),
                          ),
                          if (_isAvatarUpdating)
                            Positioned.fill(
                              child: ColoredBox(
                                color: Colors.black38,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
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
                                color: AppColors.primary.withValues(alpha: 0.1),
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
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 0,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton.icon(
                                  onPressed: _isAvatarUpdating
                                      ? null
                                      : () {
                                          Navigator.pop(sheetContext);
                                          _pickAndUploadAvatar(repo);
                                        },
                                  icon: const Icon(
                                    Icons.file_upload_outlined,
                                    size: 17,
                                  ),
                                  label: Text(
                                    profile.avatarUrl?.isNotEmpty == true
                                        ? 'Đổi ảnh'
                                        : 'Tải ảnh lên',
                                  ),
                                ),
                                if (profile.avatarUrl?.isNotEmpty == true)
                                  IconButton(
                                    tooltip: 'Xóa ảnh đại diện',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _isAvatarUpdating
                                        ? null
                                        : () {
                                            Navigator.pop(sheetContext);
                                            _deleteAvatar(repo);
                                          },
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 19,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final active =
        icon == Icons.check_circle_outline_rounded &&
        value == MemberStatus.active.label;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.statusSuccessSoft
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? AppColors.statusSuccess : AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
