import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../data/liturgical_models.dart';

class LiturgicalDayDialog extends StatelessWidget {
  final DateTime date;
  final List<LiturgicalEvent> events;
  final List<RehearsalSession> rehearsals;

  const LiturgicalDayDialog({
    super.key,
    required this.date,
    this.events = const [],
    this.rehearsals = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    List<LiturgicalEvent> events = const [],
    List<RehearsalSession> rehearsals = const [],
  }) => showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) =>
        LiturgicalDayDialog(date: date, events: events, rehearsals: rehearsals),
  );

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM/yyyy').format(date);
    final weekday = const [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ][date.weekday - 1];
    final activityCount = events.length + rehearsals.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              color: AppColors.primary,
              child: Text(
                dateLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekday,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activityCount == 0
                          ? 'Không có sự kiện hoặc buổi tập được công bố cho ngày này.'
                          : '$activityCount hoạt động được công bố cho ngày này.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    if (events.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('SỰ KIỆN SẮP TỚI'),
                      for (final event in events) ...[
                        const SizedBox(height: 8),
                        _activityCard(
                          title: event.title,
                          subtitle: event.location,
                          time: event.timeRange,
                          actionLabel: 'Chi tiết sự kiện',
                          onAction: () {
                            Navigator.of(context).pop();
                            context.push(
                              '/event/${Uri.encodeComponent(event.id)}',
                            );
                          },
                        ),
                      ],
                    ],
                    if (rehearsals.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('BUỔI TẬP ĐƯỢC GIAO'),
                      for (final rehearsal in rehearsals) ...[
                        const SizedBox(height: 8),
                        _activityCard(
                          title: rehearsal.title,
                          subtitle: [
                            if (rehearsal.location.isNotEmpty)
                              rehearsal.location,
                            if (rehearsal.note?.trim().isNotEmpty ?? false)
                              'Ghi chú: ${rehearsal.note!.trim()}',
                          ].join('\n'),
                          time: rehearsal.timeRange,
                          actionLabel: 'Chi tiết buổi tập',
                          onAction: () {
                            Navigator.of(context).pop();
                            context.push(
                              '/rehearsal/${Uri.encodeComponent(rehearsal.id)}',
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: AppTypography.labelSmall.copyWith(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      fontSize: 11,
    ),
  );

  Widget _activityCard({
    required String title,
    required String subtitle,
    required String time,
    required String actionLabel,
    required VoidCallback onAction,
  }) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                time.isNotEmpty ? '$time • $subtitle' : subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
