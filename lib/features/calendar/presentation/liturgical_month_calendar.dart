import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../data/calendar_dto.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';
import 'liturgical_day_dialog.dart';

/// Month calendar view styled after Image 1 (Semester Schedule layout).
/// Allows choosing month and year, displays Sunday-to-Saturday columns,
/// highlights today/selected date, shows indicator dots on active liturgical days,
/// and opens the [LiturgicalDayDialog] when tapping on any day.
class LiturgicalMonthCalendar extends ConsumerStatefulWidget {
  final List<LiturgicalEvent> events;
  final List<RehearsalSession> rehearsals;
  final DateTime initialDate;

  const LiturgicalMonthCalendar({
    super.key,
    this.events = const [],
    this.rehearsals = const [],
    required this.initialDate,
  });

  @override
  ConsumerState<LiturgicalMonthCalendar> createState() =>
      _LiturgicalMonthCalendarState();
}

class _LiturgicalMonthCalendarState
    extends ConsumerState<LiturgicalMonthCalendar> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
    _selectedDate = widget.initialDate;
  }

  LiturgicalDateRange get _monthRange {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    return (
      fromDate: DateFormat('yyyy-MM-dd').format(firstDay),
      toDate: DateFormat('yyyy-MM-dd').format(lastDay),
    );
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + 1,
        1,
      );
    });
  }


  Future<void> _pickMonthYear(BuildContext context) async {
    int tempYear = _currentMonth.year;
    int tempMonth = _currentMonth.month;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              title: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chọn tháng và năm',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year selector row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () =>
                              setDialogState(() => tempYear = tempYear - 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$tempYear',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () =>
                              setDialogState(() => tempYear = tempYear + 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Months 1 to 12 grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final monthNum = index + 1;
                        final isSelected =
                            monthNum == tempMonth && tempYear == _currentMonth.year;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setDialogState(() => tempMonth = monthNum);
                            Navigator.of(ctx).pop(DateTime(tempYear, monthNum, 1));
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Tháng $monthNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    final now = DateTime.now();
                    Navigator.of(ctx).pop(DateTime(now.year, now.month, 1));
                  },
                  child: const Text('Tháng này'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        _currentMonth = picked;
      });
    }
  }

  bool _hasIndicatorDot(
    DateTime dayDate,
    LiturgicalDay? liturgicalDay,
  ) {
    // Check if choir event or rehearsal exists on this day
    if (widget.events.any((e) => DateUtils.isSameDay(e.date, dayDate))) {
      return true;
    }
    if (widget.rehearsals.any((r) => DateUtils.isSameDay(r.date, dayDate))) {
      return true;
    }
    if (liturgicalDay == null) return false;

    // Sundays always have mass/celebrations
    if (dayDate.weekday == DateTime.sunday) return true;

    // Check rank for feasts / memorials / solemnities
    final rank = liturgicalDay.rank?.toLowerCase();
    if (rank != null &&
        rank.isNotEmpty &&
        !rank.contains('weekday') &&
        !rank.contains('feria')) {
      return true;
    }

    // Check celebration name: special saints or solemnities
    final name = liturgicalDay.celebrationName.toLowerCase();
    if (!name.contains('weekday') &&
        !name.contains('feria') &&
        !name.startsWith('thứ ')) {
      return true;
    }

    return false;
  }

  void _onDayTapped(
    DateTime dayDate,
    LiturgicalDay? liturgicalDay,
    bool isLoading,
  ) {
    setState(() {
      _selectedDate = dayDate;
    });

    final dayEvents = widget.events
        .where((e) => DateUtils.isSameDay(e.date, dayDate))
        .toList();
    final dayRehearsals = widget.rehearsals
        .where((r) => DateUtils.isSameDay(r.date, dayDate))
        .toList();

    LiturgicalDayDialog.show(
      context,
      date: dayDate,
      liturgicalDay: liturgicalDay,
      events: dayEvents,
      rehearsals: dayRehearsals,
      isLoading: isLoading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysState = ref.watch(liturgicalDaysProvider(_monthRange));
    final liturgicalDays = daysState.asData?.value ?? const <LiturgicalDay>[];
    final today = DateUtils.dateOnly(DateTime.now());

    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    // Sunday-first offset: Sunday (weekday 7) -> 0, Monday (1) -> 1, ..., Saturday (6) -> 6
    final startOffset = firstWeekday % 7;
    final totalCells = startOffset + daysInMonth;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Month Selector Header matching Image 1: "October 2026 ▾"
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                tooltip: 'Tháng trước',
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: _previousMonth,
              ),
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _pickMonthYear(context),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Tháng ${_currentMonth.month}, ${_currentMonth.year}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Color(0xFFE65100),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                tooltip: 'Tháng sau',
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Weekday Labels Row matching Image 1: CN, Th2, Th3, Th4, Th5, Th6, Th7
          Row(
            children: const [
              _WeekdayHeader('CN'),
              _WeekdayHeader('Th2'),
              _WeekdayHeader('Th3'),
              _WeekdayHeader('Th4'),
              _WeekdayHeader('Th5'),
              _WeekdayHeader('Th6'),
              _WeekdayHeader('Th7'),
            ],
          ),
          const SizedBox(height: 8),

          // Loading bar if fetching liturgical days from BE API
          if (daysState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          // Month Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return const SizedBox.shrink();
              }
              final dayNumber = index - startOffset + 1;
              final dayDate = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                dayNumber,
              );
              final isToday = DateUtils.isSameDay(dayDate, today);
              final isSelected = _selectedDate != null &&
                  DateUtils.isSameDay(dayDate, _selectedDate!);

              final dayData = liturgicalDays
                  .where((d) => DateUtils.isSameDay(d.date, dayDate))
                  .firstOrNull;

              final hasDot = _hasIndicatorDot(dayDate, dayData);

              return _CalendarDayCell(
                dayNumber: dayNumber,
                isToday: isToday,
                isSelected: isSelected,
                hasDot: hasDot,
                onTap: () =>
                    _onDayTapped(dayDate, dayData, daysState.isLoading),
              );
            },
          ),

          if (daysState.hasError) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusDangerSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.statusDanger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chưa tải được lịch phụng vụ từ máy chủ.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.statusDanger,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(liturgicalDaysProvider(_monthRange)),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(60, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Thử lại', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;
  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int dayNumber;
  final bool isToday;
  final bool isSelected;
  final bool hasDot;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.dayNumber,
    required this.isToday,
    required this.isSelected,
    required this.hasDot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // In Image 1, today (e.g. 21) is highlighted in orange.
    Color textColor;
    if (isToday) {
      textColor = const Color(0xFFE65100);
    } else if (isSelected) {
      textColor = AppColors.primary;
    } else {
      textColor = const Color(0xFF1E293B);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('calendar-month-day-$dayNumber'),
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFFE65100), width: 1.5)
                : null,
            color: isSelected
                ? const Color(0xFFFFF7ED)
                : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNumber',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 3),
              // Green dot indicator matching Image 1
              Container(
                width: 4.5,
                height: 4.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasDot
                      ? const Color(0xFF16A34A) // Dark green dot like Image 1
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
