import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../data/calendar_dto.dart';
import '../data/liturgical_models.dart';

/// Modal dialog displaying liturgical day details and scheduled activities
/// for a selected day, styled after the semester schedule card design.
class LiturgicalDayDialog extends StatelessWidget {
  final DateTime date;
  final LiturgicalDay? liturgicalDay;
  final List<LiturgicalEvent> events;
  final List<RehearsalSession> rehearsals;
  final bool isLoading;

  const LiturgicalDayDialog({
    super.key,
    required this.date,
    this.liturgicalDay,
    this.events = const [],
    this.rehearsals = const [],
    this.isLoading = false,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    LiturgicalDay? liturgicalDay,
    List<LiturgicalEvent> events = const [],
    List<RehearsalSession> rehearsals = const [],
    bool isLoading = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LiturgicalDayDialog(
        date: date,
        liturgicalDay: liturgicalDay,
        events: events,
        rehearsals: rehearsals,
        isLoading: isLoading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yyyy').format(date);
    final dayOfWeek = const [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chúa Nhật',
    ][date.weekday - 1];

    final celebrationTitle = liturgicalDay?.celebrationLabel ??
        (date.weekday == DateTime.sunday
            ? 'Chúa Nhật'
            : '$dayOfWeek trong tuần');
    final rank = liturgicalDay?.rankLabel;
    final season = liturgicalDay?.seasonLabel ?? 'Mùa Thường Niên';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
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
            // Dark Navy Header matching Image 2
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              color: const Color(0xFF1B2A4A),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card Body with left vertical colored accent bar
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Orange / Accent vertical stripe
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Main Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Badges row: Rank badge + Season/Time
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFFFB74D),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    rank ?? (date.weekday == DateTime.sunday ? 'Chúa Nhật' : 'Ngày Thường'),
                                    style: const TextStyle(
                                      color: Color(0xFFE65100),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  dayOfWeek,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Rounded Soft Pill for Season / Liturgical Context
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MÙA PHỤNG VỤ',
                                    style: AppTypography.labelSmall.copyWith(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    season,
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Celebration title from Liturgical Calendar API
                            Text(
                              celebrationTitle,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Liturgical details
                            if (rank != null) ...[
                              _metaRow('Bậc lễ', rank),
                              const SizedBox(height: 4),
                            ],
                            _metaRow('Lịch phụng vụ', 'Giáo hội Công giáo'),

                            // Choir Events on this day
                            if (events.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              Text(
                                'THÁNH LỄ CA ĐOÀN',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              for (final event in events) ...[
                                const SizedBox(height: 6),
                                _activityCard(
                                  title: event.title,
                                  subtitle: event.location,
                                  time: event.timeRange,
                                  actionLabel: 'Chi tiết lễ',
                                  onAction: () {
                                    Navigator.of(context).pop();
                                    context.push('/event/${Uri.encodeComponent(event.id)}');
                                  },
                                ),
                              ],
                            ],

                            // Rehearsals on this day
                            if (rehearsals.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              Text(
                                'BUỔI TẬP HÁT',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              for (final rehearsal in rehearsals) ...[
                                const SizedBox(height: 6),
                                _activityCard(
                                  title: rehearsal.title,
                                  subtitle: rehearsal.location,
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

                            // Action buttons at bottom (green pill like PRESENT in Image 2)
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.muted,
                                  ),
                                  child: const Text('Đóng'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    'Xác nhận',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(
            '$label:',
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _activityCard({
    required String title,
    required String subtitle,
    required String time,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
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
                  maxLines: 1,
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
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 32),
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
}
