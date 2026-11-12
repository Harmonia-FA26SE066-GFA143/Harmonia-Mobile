import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_messages.dart';
import '../../auth/data/auth_dto.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../lookups/data/lookup_dto.dart';
import '../../lookups/data/lookups_api_service.dart';
import '../../calendar/data/calendar_repository.dart'
    show publicAppSettingsProvider;
import '../../practice/data/practice_repository.dart'
    show practiceSubmissionsNotifierProvider;
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
                        backgroundColor: AppColors.primary,
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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Theme(
        data: MemberChoirStyle.theme(context),
        child: FutureBuilder<List<SkillDto>>(
          future: skillsRequest,
          builder: (context, snapshot) => StatefulBuilder(
            builder: (context, setModalState) {
              final loading = snapshot.connectionState != ConnectionState.done;
              final availableSkills = snapshot.data ?? const <SkillDto>[];
              selectedSkill ??= availableSkills.firstOrNull;
              void close() => Navigator.of(context).pop();

              Future<void> submit() async {
                final skill = selectedSkill;
                if (isSubmitting || skill == null) return;
                final messenger = ScaffoldMessenger.of(this.context);
                setModalState(() {
                  isSubmitting = true;
                  errorMessage = null;
                });

                try {
                  final declared = await repo.declareNewSkill(
                    skillId: skill.id,
                    level: selectedLevel.wireName,
                    name: skill.name,
                  );
                  final evidence = evidencePath;
                  Object? uploadError;
                  if (evidence != null) {
                    try {
                      await repo.uploadSkillEvidence(
                        id: declared.id,
                        filePath: evidence,
                      );
                    } catch (error) {
                      uploadError = error;
                    }
                  }
                  if (!mounted || !context.mounted) return;
                  close();
                  ref.invalidate(currentMemberSkillsProvider);
                  unawaited(
                    ref.read(memberSkillsNotifierProvider.notifier).refresh(),
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        uploadError != null
                            ? 'Bản khai đã gửi, nhưng minh chứng chưa tải lên: ${ErrorMessages.forException(uploadError)}. Mở kỹ năng vừa khai báo để thử gửi lại.'
                            : evidence == null
                            ? 'Đã gửi bản khai kỹ năng thành công! Đang chờ duyệt.'
                            : 'Đã gửi bản khai và minh chứng thành công. Đang chờ duyệt.',
                      ),
                      backgroundColor: uploadError == null
                          ? AppColors.statusSuccess
                          : null,
                    ),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  setModalState(() {
                    isSubmitting = false;
                    errorMessage =
                        'Không thể gửi bản khai: ${ErrorMessages.forException(error)}';
                  });
                }
              }

              return PopScope(
                canPop: !isSubmitting,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: FractionallySizedBox(
                    heightFactor: .93,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 10,
                              children: [
                                const CircleAvatar(
                                  backgroundColor: MemberChoirStyle.blush,
                                  foregroundColor: MemberChoirStyle.wine,
                                  child: Icon(Icons.menu_book_outlined),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 4,
                                    children: [
                                      Text(
                                        'Khai báo kỹ năng mới',
                                        style: AppTypography.headlineSmall
                                            .copyWith(
                                              fontFamily:
                                                  MemberChoirStyle.displayFont,
                                              color: MemberChoirStyle.ink,
                                            ),
                                      ),
                                      Text(
                                        'Bản khai sẽ được gửi tới Ca trưởng xem xét và phê duyệt.',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Đóng',
                                  onPressed: isSubmitting ? null : close,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Chuyên môn phụng vụ đăng ký *',
                                    style: AppTypography.titleMedium,
                                  ),
                                  const SizedBox(height: 10),
                                  if (loading)
                                    const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  else if (availableSkills.isEmpty)
                                    Text(
                                      snapshot.hasError
                                          ? ErrorMessages.forException(
                                              snapshot.error,
                                              defaultMessage: 'Không thể tải danh sách kỹ năng.',
                                            )
                                          : 'Không có danh mục kỹ năng khả dụng.',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.statusDanger,
                                      ),
                                    )
                                  else
                                    RadioGroup<SkillDto>(
                                      groupValue: selectedSkill,
                                      onChanged: (skill) {
                                        if (isSubmitting || skill == null) {
                                          return;
                                        }
                                        setModalState(
                                          () => selectedSkill = skill,
                                        );
                                      },
                                      child: Column(
                                        spacing: 8,
                                        children: [
                                          for (final skill in availableSkills)
                                            RadioListTile<SkillDto>(
                                              value: skill,
                                              enabled: !isSubmitting,
                                              selected: skill == selectedSkill,
                                              controlAffinity:
                                                  ListTileControlAffinity
                                                      .trailing,
                                              title: Text(
                                                skill.name,
                                                style:
                                                    AppTypography.titleMedium,
                                              ),
                                              subtitle:
                                                  skill.description
                                                          ?.trim()
                                                          .isNotEmpty ==
                                                      true
                                                  ? Text(skill.description!)
                                                  : null,
                                              secondary: const CircleAvatar(
                                                backgroundColor:
                                                    MemberChoirStyle
                                                        .serviceCanvas,
                                                foregroundColor:
                                                    MemberChoirStyle.ink,
                                                child: Icon(
                                                  Icons.music_note_rounded,
                                                  size: 20,
                                                ),
                                              ),
                                              selectedTileColor:
                                                  MemberChoirStyle.blush,
                                              tileColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                side: BorderSide(
                                                  color: skill == selectedSkill
                                                      ? MemberChoirStyle.wine
                                                      : MemberChoirStyle.border,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Cấp độ năng lực',
                                    style: AppTypography.labelLarge,
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<SkillLevel>(
                                    initialValue: selectedLevel,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      fillColor: MemberChoirStyle.paper,
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
                                            child: Text(
                                              l.label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: isSubmitting
                                        ? null
                                        : (val) {
                                            if (val != null) {
                                              setModalState(
                                                () => selectedLevel = val,
                                              );
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
                                      backgroundColor: MemberChoirStyle.paper,
                                      side: const BorderSide(
                                        color: MemberChoirStyle.border,
                                      ),
                                    ),
                                    onPressed: isSubmitting
                                        ? null
                                        : () async {
                                            try {
                                              final path =
                                                  await MemberSkillEvidencePicker()
                                                      .pickFile();
                                              if (path == null ||
                                                  !context.mounted) {
                                                return;
                                              }
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
                                                  _deleteTemporaryEvidence(
                                                    previousPath,
                                                  ),
                                                );
                                              }
                                            } catch (error) {
                                              if (!context.mounted) return;
                                              setModalState(() {
                                                errorMessage =
                                                    ErrorMessages.forException(
                                                      error,
                                                      defaultMessage: 'Không thể mở thư viện tệp.',
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
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: isSubmitting
                                                ? null
                                                : () {
                                                    final previousPath =
                                                        evidencePath;
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
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                            ),
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
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          if (errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Text(
                                errorMessage!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.statusDanger,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                            child: Row(
                              spacing: 10,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                  ),
                                  onPressed: isSubmitting ? null : close,
                                  child: const Text('Hủy'),
                                ),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed:
                                        isSubmitting || selectedSkill == null
                                        ? null
                                        : submit,
                                    icon: isSubmitting
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send_outlined,
                                            size: 18,
                                          ),
                                    label: const Text(
                                      'Gửi bản khai kỹ năng',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
    final skills = ref.watch(memberSkillsNotifierProvider);
    final skillsNotifier = ref.read(memberSkillsNotifierProvider.notifier);
    final profileFuture = ref.watch(currentMemberProfileProvider.future);
    final settings = ref.watch(publicAppSettingsProvider).asData?.value;
    final choir = [settings?.choirName, settings?.parishName].nonNulls
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .join(' · ');
    final busy = ref.watch(
      authNotifierProvider.select((auth) => auth.isLoading),
    );

    return Theme(
      data: MemberChoirStyle.theme(context),
      child: FutureBuilder<MemberProfileDto>(
        key: _profileRefreshKey,
        future: profileFuture,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final loading = snapshot.connectionState == ConnectionState.waiting;
          return Scaffold(
            backgroundColor: MemberChoirStyle.paper,
            appBar: AppPageHeader(
              gradient: MemberChoirStyle.header,
              titleFontFamily: MemberChoirStyle.displayFont,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (choir.isNotEmpty)
                    Text(
                      choir,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: MemberChoirStyle.softGold,
                      ),
                    ),
                  const Text(
                    'Hồ sơ ca viên',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Ảnh đại diện',
                  onPressed: profile == null || _isAvatarUpdating
                      ? null
                      : () => _showAvatarActions(repo, profile),
                  icon: _isAvatarUpdating
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError || profile == null
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 12,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: AppColors.statusDanger,
                            ),
                            const Text(
                              'Không thể tải dữ liệu hồ sơ từ máy chủ.',
                              textAlign: TextAlign.center,
                            ),
                            ElevatedButton(
                              onPressed: _refreshProfile,
                              child: const Text('Thử lại'),
                            ),
                            TextButton.icon(
                              onPressed: busy
                                  ? null
                                  : () => _showLogoutDialog(context),
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Đăng xuất'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        StitchEntrance(
                          child: _ProfileSummary(
                            profile: profile,
                            onEdit: () =>
                                _showEditProfileDialog(context, repo, profile),
                            onAvatar: _isAvatarUpdating
                                ? null
                                : () => _showAvatarActions(repo, profile),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ProfileSectionHeading(
                          title: 'Kỹ năng & Thẩm định chuyên môn',
                          action: TextButton.icon(
                            onPressed: () =>
                                _showDeclareSkillDialog(context, repo),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Khai báo'),
                          ),
                        ),
                        if (skills.isLoading && skills.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (skills.errorMessage != null &&
                            skills.items.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Text(
                                    skills.errorMessage!,
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton(
                                    onPressed: skillsNotifier.loadInitial,
                                    child: const Text('Thử lại'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (skills.items.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Bạn chưa khai báo kỹ năng nào.'),
                            ),
                          )
                        else ...[
                          for (final skill in skills.items)
                            _ProfileSkillCard(
                              skill: skill,
                              onTap: () =>
                                  _showSkillDetailDialog(context, skill.id),
                            ),
                          if (skills.hasNextPage)
                            if (skills.isLoadingMore)
                              const Center(child: CircularProgressIndicator())
                            else if (skills.loadMoreErrorMessage != null)
                              Column(
                                children: [
                                  Text(
                                    skills.loadMoreErrorMessage!,
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton(
                                    onPressed: skillsNotifier.loadMore,
                                    child: const Text('Thử lại'),
                                  ),
                                ],
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: skillsNotifier.loadMore,
                                icon: const Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 16,
                                ),
                                label: const Text('Tải thêm kỹ năng'),
                              ),
                        ],
                        const SizedBox(height: 20),
                        const _ProfileRecentPractice(),
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.workspace_premium_outlined,
                              color: MemberChoirStyle.wine,
                            ),
                            title: const Text('Đề cử ca trưởng của tôi'),
                            subtitle: const Text(
                              'Theo dõi đề cử đã duyệt và lịch sử đào tạo',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/director-nominations'),
                          ),
                        ),
                        if (profile.id.isNotEmpty)
                          Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.copy_outlined,
                                color: MemberChoirStyle.wine,
                              ),
                              title: const Text('Sao chép mã hồ sơ ca viên'),
                              onTap: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: profile.id),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã sao chép mã hồ sơ.'),
                                  ),
                                );
                              },
                            ),
                          ),
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.history_rounded,
                              color: MemberChoirStyle.wine,
                            ),
                            title: const Text('Lịch sử tham gia & luyện tập'),
                            subtitle: const Text(
                              'Xem kết quả phục vụ lễ và bài tập đã hoàn thành',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/profile/history'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _ProfileSectionHeading(
                          title: 'Cài đặt tài khoản',
                        ),
                        Card(
                          child: ListTile(
                            enabled: !busy,
                            leading: const Icon(
                              Icons.lock_reset_rounded,
                              color: MemberChoirStyle.wine,
                            ),
                            title: const Text('Đổi mật khẩu'),
                            subtitle: const Text(
                              'Cập nhật mật khẩu đăng nhập Harmonia',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/change-password'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.statusDanger,
                          ),
                          onPressed: busy
                              ? null
                              : () => _showLogoutDialog(context),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Đăng xuất'),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
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
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.profile,
    required this.onEdit,
    required this.onAvatar,
  });

  final MemberProfileDto profile;
  final VoidCallback onEdit;
  final VoidCallback? onAvatar;

  @override
  Widget build(BuildContext context) {
    final active = profile.status == MemberStatus.active;
    final foreground = active ? AppColors.statusSuccess : AppColors.body;
    final name = profile.fullName.trim();
    final fallback = Center(
      child: Text(
        name.isEmpty ? 'H' : name.characters.first.toUpperCase(),
        style: AppTypography.headlineSmall.copyWith(
          color: MemberChoirStyle.wine,
        ),
      ),
    );
    final contacts = [
      (Icons.email_outlined, 'Email', profile.email),
      (Icons.phone_outlined, 'Số điện thoại', profile.phone),
      (Icons.cake_outlined, 'Ngày sinh', profile.dateOfBirth),
      (Icons.calendar_month_outlined, 'Ngày tham gia', profile.joinedDate),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              spacing: 12,
              children: [
                InkWell(
                  onTap: onAvatar,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 76,
                    height: 76,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MemberChoirStyle.blush,
                      border: Border.all(
                        color: MemberChoirStyle.gold,
                        width: 2,
                      ),
                    ),
                    child: profile.avatarUrl?.trim().isNotEmpty == true
                        ? Image.network(
                            profile.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => fallback,
                          )
                        : fallback,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 5,
                    children: [
                      _ProfileBadge(
                        label: profile.status.label,
                        color: foreground,
                        fill: active
                            ? AppColors.statusSuccessSoft
                            : MemberChoirStyle.paper,
                        icon: active
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline,
                      ),
                      Text(
                        profile.fullName,
                        style: AppTypography.headlineSmall.copyWith(
                          color: MemberChoirStyle.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 1, color: MemberChoirStyle.border),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 275 &&
                        MediaQuery.textScalerOf(context).scale(14) < 21
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    for (final (icon, label, value) in contacts)
                      SizedBox(
                        width: width,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 7,
                          children: [
                            Icon(icon, size: 17, color: MemberChoirStyle.wine),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  Text(
                                    value?.trim().isNotEmpty == true
                                        ? value!
                                        : 'Chưa cập nhật',
                                    style: AppTypography.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: MemberChoirStyle.paper,
              ),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Chỉnh sửa thông tin cá nhân'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSectionHeading extends StatelessWidget {
  const _ProfileSectionHeading({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      spacing: 8,
      children: [
        Container(width: 3, height: 20, color: MemberChoirStyle.wine),
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleLarge.copyWith(
              color: MemberChoirStyle.ink,
            ),
          ),
        ),
        if (action case final widget?) Flexible(child: widget),
      ],
    ),
  );
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    required this.label,
    required this.color,
    required this.fill,
    required this.icon,
  });

  final String label;
  final Color color, fill;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          Icon(icon, size: 13, color: color),
          Flexible(
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileSkillCard extends StatelessWidget {
  const _ProfileSkillCard({required this.skill, required this.onTap});

  final MemberSkill skill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, fill, icon) = switch (skill.status) {
      SkillApprovalStatus.approved => (
        AppColors.statusSuccess,
        AppColors.statusSuccessSoft,
        Icons.check_circle_outline,
      ),
      SkillApprovalStatus.pending => (
        AppColors.statusWarning,
        AppColors.statusWarningSoft,
        Icons.hourglass_top_rounded,
      ),
      SkillApprovalStatus.rejected => (
        AppColors.statusDanger,
        AppColors.statusDangerSoft,
        Icons.info_outline,
      ),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              const CircleAvatar(
                backgroundColor: MemberChoirStyle.paper,
                foregroundColor: MemberChoirStyle.wine,
                child: Icon(Icons.music_note_rounded, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(skill.name, style: AppTypography.titleMedium),
                    Text(
                      '${skill.categoryName} · Cấp độ: ${skill.levelLabel}',
                      style: AppTypography.bodySmall,
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _ProfileBadge(
                          label: skill.status.label,
                          color: color,
                          fill: fill,
                          icon: icon,
                        ),
                        if (skill.approvedAt case final date?)
                          Text(
                            DateFormat('dd/MM/yyyy').format(date),
                            style: AppTypography.labelSmall,
                          ),
                      ],
                    ),
                    if (skill.rejectReason?.trim().isNotEmpty == true &&
                        skill.status == SkillApprovalStatus.rejected)
                      Text(
                        'Lý do từ chối: ${skill.rejectReason!}',
                        style: AppTypography.bodySmall.copyWith(color: color),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: MemberChoirStyle.wine,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRecentPractice extends ConsumerWidget {
  const _ProfileRecentPractice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref
        .watch(practiceSubmissionsNotifierProvider(null))
        .items
        .take(3);
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileSectionHeading(
          title: 'Luyện tập gần đây',
          action: TextButton(
            onPressed: () => context.push('/practice-history'),
            child: const Text('Xem tất cả'),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (final submission in recent)
                ListTile(
                  leading: const Icon(
                    Icons.headphones_rounded,
                    color: MemberChoirStyle.wine,
                  ),
                  title: Text(
                    submission.assignmentTitle?.trim().isNotEmpty == true
                        ? submission.assignmentTitle!
                        : 'Bản thu lần ${submission.attemptNo}',
                  ),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy · HH:mm')
                        .format(submission.submittedAt),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(
                    '/practice-submission/${Uri.encodeComponent(submission.id)}',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
