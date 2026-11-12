import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/widgets/app_page_header.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/error_messages.dart';
import 'participation_prompt.dart';
import '../../music/data/music_repository.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';

class LiturgicalEventDetailScreen extends ConsumerWidget {
  final String eventId;

  const LiturgicalEventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(eventDetailProvider(eventId));
    final songListAsync = ref.watch(eventApprovedSongListProvider(eventId));
    const pageTitle = Text('Chi tiết phục vụ');
    if (detailState.isLoading) {
      return Scaffold(
        backgroundColor: MemberChoirStyle.serviceCanvas,
        appBar: const AppPageHeader(
          centerTitle: true,
          title: pageTitle,
          gradient: MemberChoirStyle.header,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (detailState.hasError) {
      return Scaffold(
        backgroundColor: MemberChoirStyle.serviceCanvas,
        appBar: const AppPageHeader(
          centerTitle: true,
          title: pageTitle,
          gradient: MemberChoirStyle.header,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ErrorMessages.forException(detailState.error)),
              TextButton(
                onPressed: () => ref.invalidate(eventDetailProvider(eventId)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    final detail = detailState.requireValue;
    final event = detail.event;
    final respondedAt = detail.participation?.respondedAt?.toLocal();
    final responseAction = switch (event.participationStatus) {
      ParticipationStatus.confirmed => 'Đã xác nhận tham gia',
      ParticipationStatus.declined => 'Đã báo vắng',
      ParticipationStatus.unsure => 'Đã chọn chưa chắc chắn',
      ParticipationStatus.unknown ||
      ParticipationStatus.invited => 'Đã phản hồi',
    };

    return Theme(
      data: MemberChoirStyle.theme(context),
      child: Scaffold(
        backgroundColor: MemberChoirStyle.serviceCanvas,
        appBar: AppPageHeader(
          centerTitle: true,
          title: pageTitle,
          gradient: MemberChoirStyle.header,
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(eventDetailProvider(eventId));
                ref.invalidate(eventApprovedSongListProvider(eventId));
              },
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: MemberChoirStyle.ink,
                  child: Stack(
                    children: [
                      const MemberChoirArt(
                        artwork: MemberChoirArtwork.service,
                        height: 204,
                        alignment: Alignment.topCenter,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, MemberChoirStyle.ink],
                          stops: [0.42, 1],
                        ),
                      ),
                      if (event.seasonName.isNotEmpty)
                        Positioned(
                          left: 16,
                          right: 16,
                          top: 12,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 6,
                                  children: [
                                    const Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: AppColors.statusSuccess,
                                    ),
                                    Flexible(
                                      child: Text(
                                        event.seasonName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: MemberChoirStyle.ink,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 144, 12, 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: MemberChoirStyle.blush,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Text(
                                        event.assignedVocalPart.isEmpty
                                            ? 'Chưa có thông tin phân công'
                                            : 'Phân công: ${event.assignedVocalPart}',
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: MemberChoirStyle.wine,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  event.title,
                                  style: AppTypography.headlineMedium.copyWith(
                                    color: MemberChoirStyle.ink,
                                    fontFamily: MemberChoirStyle.displayFont,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const _EventMetaIcon(
                                      Icons.calendar_month_outlined,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        DateFormat(
                                          'EEEE, dd/MM/yyyy',
                                          'vi',
                                        ).format(event.date),
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const _EventMetaIcon(
                                      Icons.access_time_rounded,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      event.timeRange,
                                      style: AppTypography.bodyMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const _EventMetaIcon(Icons.church_outlined),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        event.location,
                                        style: AppTypography.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (detail.specialRequirements?.isNotEmpty == true)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hướng dẫn phục vụ',
                                  style: AppTypography.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(detail.specialRequirements!),
                              ],
                            ),
                          ),
                        ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _ServiceSectionTitle('Phân công của bạn'),
                              if (detail.assignments.isEmpty)
                                const Text('Chưa có phân công được công bố.'),
                              for (final assignment in detail.assignments)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.assignment_ind),
                                  title: Text(assignment.skillName),
                                  subtitle:
                                      assignment.songTitle == null &&
                                          assignment.note?.trim().isNotEmpty !=
                                              true
                                      ? null
                                      : Text(
                                          [
                                            ?assignment.songTitle,
                                            if (assignment.note
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true)
                                              assignment.note!,
                                          ].join('\n'),
                                        ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Participation response
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OverflowBar(
                                alignment: MainAxisAlignment.spaceBetween,
                                spacing: 12,
                                overflowSpacing: 8,
                                overflowAlignment: OverflowBarAlignment.start,
                                children: [
                                  const _ServiceSectionTitle(
                                    'Xác nhận tham gia',
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: _participationColor(
                                          event.participationStatus,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          event.participationStatus.label,
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                color: _participationColor(
                                                  event.participationStatus,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ParticipationOption(
                                      label: 'Xác nhận',
                                      status: ParticipationStatus.confirmed,
                                      selected:
                                          event.participationStatus ==
                                          ParticipationStatus.confirmed,
                                      enabled: event.canRespond,
                                      onPressed: () => showParticipationPrompt(
                                        context,
                                        ref,
                                        event,
                                        ParticipationStatus.confirmed,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _ParticipationOption(
                                      label: 'Báo vắng',
                                      status: ParticipationStatus.declined,
                                      selected:
                                          event.participationStatus ==
                                          ParticipationStatus.declined,
                                      enabled: event.canRespond,
                                      onPressed: () => showParticipationPrompt(
                                        context,
                                        ref,
                                        event,
                                        ParticipationStatus.declined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _ParticipationOption(
                                      label: 'Chưa chắc',
                                      status: ParticipationStatus.unsure,
                                      selected:
                                          event.participationStatus ==
                                          ParticipationStatus.unsure,
                                      enabled: event.canRespond,
                                      onPressed: () => showParticipationPrompt(
                                        context,
                                        ref,
                                        event,
                                        ParticipationStatus.unsure,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (respondedAt != null) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_outlined,
                                      size: 15,
                                      color: _participationColor(
                                        event.participationStatus,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '$responseAction lúc ${DateFormat('HH:mm').format(respondedAt)} ngày ${DateFormat('dd/MM/yyyy').format(respondedAt)}',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (!event.canRespond &&
                                  event.cannotRespondReason != null &&
                                  event.cannotRespondReason !=
                                      'EVENT_PARTICIPATION_ALREADY_RESPONDED') ...[
                                const SizedBox(height: 8),
                                Text(
                                  participationStatusMessage(event),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OverflowBar(
                                alignment: MainAxisAlignment.spaceBetween,
                                spacing: 12,
                                overflowSpacing: 8,
                                overflowAlignment: OverflowBarAlignment.start,
                                children: [
                                  const _ServiceSectionTitle(
                                    'Lịch trình tập hát',
                                  ),
                                  Text(
                                    '${detail.rehearsals.length} BUỔI TẬP',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (detail.rehearsals.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Chưa có lịch tập hát được công bố.',
                                  ),
                                )
                              else
                                for (final item in detail.rehearsals)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Material(
                                      color: AppColors.surface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () => context.push(
                                          '/rehearsal/${Uri.encodeComponent(item.rehearsal.id)}',
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: const Icon(
                                                  Icons.timer_outlined,
                                                  size: 18,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item.rehearsal.title,
                                                      style: AppTypography
                                                          .bodyMedium
                                                          .copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      '${DateFormat('dd/MM/yyyy').format(item.rehearsal.date)} • ${item.rehearsal.timeRange}',
                                                      style: AppTypography
                                                          .bodySmall
                                                          .copyWith(
                                                            color:
                                                                AppColors.muted,
                                                          ),
                                                    ),
                                                    if (item
                                                        .rehearsal
                                                        .location
                                                        .isNotEmpty)
                                                      Text(
                                                        item.rehearsal.location,
                                                        style: AppTypography
                                                            .bodySmall
                                                            .copyWith(
                                                              color: AppColors
                                                                  .muted,
                                                            ),
                                                      ),
                                                    if (item.rehearsal.note
                                                            ?.trim()
                                                            .isNotEmpty ??
                                                        false)
                                                      Text(
                                                        'Ghi chú: ${item.rehearsal.note!.trim()}',
                                                        style: AppTypography
                                                            .bodySmall,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    item
                                                        .rehearsal
                                                        .attendanceStatus,
                                                    textAlign: TextAlign.center,
                                                    style: AppTypography
                                                        .labelSmall
                                                        .copyWith(
                                                          color:
                                                              item
                                                                      .rehearsal
                                                                      .attendanceStatus ==
                                                                  'Có mặt'
                                                              ? AppColors
                                                                    .statusSuccess
                                                              : AppColors.muted,
                                                        ),
                                                  ),
                                                  const Icon(
                                                    Icons.chevron_right,
                                                    size: 20,
                                                  ),
                                                ],
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
                      ),
                      const SizedBox(height: 24),

                      // Approved Song List Section
                      OverflowBar(
                        alignment: MainAxisAlignment.spaceBetween,
                        spacing: 12,
                        overflowSpacing: 8,
                        overflowAlignment: OverflowBarAlignment.start,
                        children: [
                          const _ServiceSectionTitle(
                            'Danh sách bài hát phụng vụ',
                          ),
                          songListAsync.when(
                            data: (songList) {
                              final hasApproved = songList != null;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: hasApproved
                                      ? AppColors.statusSuccessSoft
                                      : AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  hasApproved
                                      ? 'Đã phê duyệt'
                                      : 'Chưa có danh sách',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: hasApproved
                                        ? AppColors.statusSuccess
                                        : AppColors.muted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                            loading: () => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Đang tải...',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            error: (_, _) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.statusDangerSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Lỗi tải',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.statusDanger,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      songListAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        error: (err, _) => Card(
                          color: AppColors.statusDangerSoft,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: AppColors.statusDanger,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Không thể tải danh sách bài hát',
                                      style: TextStyle(
                                        color: AppColors.statusDanger,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Thử lại'),
                                  onPressed: () => ref.refresh(
                                    eventApprovedSongListProvider(eventId),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        data: (songList) {
                          if (songList == null) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    'Chưa có danh sách bài hát được duyệt cho sự kiện này',
                                    style: TextStyle(color: AppColors.muted),
                                  ),
                                ),
                              ),
                            );
                          }

                          if (songList.items.isEmpty) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    'Danh sách bài hát đã được duyệt nhưng chưa có bài hát nào',
                                    style: TextStyle(color: AppColors.muted),
                                  ),
                                ),
                              ),
                            );
                          }

                          final items = List.of(songList.items)
                            ..sort(
                              (a, b) =>
                                  a.displayOrder.compareTo(b.displayOrder),
                            );

                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (final (index, item) in items.indexed) ...[
                                  if (index > 0)
                                    const Divider(
                                      height: 1,
                                      color: MemberChoirStyle.border,
                                    ),
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    leading: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0xFFE8EDFC),
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(10),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.menu_book_outlined,
                                          size: 18,
                                          color: MemberChoirStyle.ink,
                                        ),
                                      ),
                                    ),
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      spacing: 4,
                                      children: [
                                        Text(
                                          '${index + 1}. ${item.slotName.isNotEmpty ? item.slotName.toUpperCase() : 'BÀI HÁT PHỤNG VỤ'}',
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                color: AppColors.tertiary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        Text(
                                          item.songTitle,
                                          style: AppTypography.titleMedium,
                                        ),
                                      ],
                                    ),
                                    subtitle:
                                        item.note?.trim().isNotEmpty == true
                                        ? Text(
                                            'Ghi chú: ${item.note}',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                                  color: AppColors.muted,
                                                ),
                                          )
                                        : null,
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: MemberChoirStyle.ink,
                                    ),
                                    onTap: () => context.push(
                                      '/song-detail/${item.songId}',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
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
  }
}

class _ServiceSectionTitle extends StatelessWidget {
  const _ServiceSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: MemberChoirStyle.gold, width: 3)),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: AppTypography.titleMedium.copyWith(
          color: MemberChoirStyle.ink,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

Color _participationColor(ParticipationStatus status) => switch (status) {
  ParticipationStatus.confirmed => AppColors.statusSuccess,
  ParticipationStatus.declined => AppColors.statusDanger,
  ParticipationStatus.unsure => AppColors.statusWarning,
  ParticipationStatus.unknown || ParticipationStatus.invited => AppColors.muted,
};

class _EventMetaIcon extends StatelessWidget {
  const _EventMetaIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 25,
    height: 25,
    decoration: BoxDecoration(
      color: MemberChoirStyle.softGold,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 15, color: AppColors.tertiary),
  );
}

class _ParticipationOption extends StatelessWidget {
  const _ParticipationOption({
    required this.label,
    required this.status,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final ParticipationStatus status;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final background = selected ? MemberChoirStyle.ink : Colors.white;
    final foreground = selected ? Colors.white : MemberChoirStyle.ink;

    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        backgroundColor: background,
        disabledBackgroundColor: selected
            ? background
            : MemberChoirStyle.serviceCanvas,
        foregroundColor: foreground,
        disabledForegroundColor: selected ? foreground : AppColors.muted,
        side: BorderSide(
          color: selected ? MemberChoirStyle.ink : MemberChoirStyle.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(switch (status) {
            ParticipationStatus.confirmed => Icons.check_rounded,
            ParticipationStatus.declined => Icons.close_rounded,
            _ => Icons.question_mark_rounded,
          }, size: 15),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            softWrap: true,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
