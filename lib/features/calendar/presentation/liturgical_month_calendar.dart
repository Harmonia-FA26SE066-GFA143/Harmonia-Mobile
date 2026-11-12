import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';
import 'liturgical_day_dialog.dart';

// Stitch tokens from "Harmonia Mobile 03 - Lịch tháng phụng vụ (Nhận diện Ca đoàn)"
// (screen 338bcc71fa754e7199dc7af8b8eb12be).
const _stitchPrimary = Color(0xFF05102B);
const _stitchPrimaryContainer = Color(0xFF1B2541);
const _stitchWineHover = Color(0xFF551D2A);
const _stitchSecondary = Color(0xFF775A00);
const _stitchSecondaryContainer = Color(0xFFFECE57);
const _stitchOnSecondaryContainer = Color(0xFF735700);
const _stitchSelectedFill = Color(0x66FFDF98);
const _stitchTodayFill = Color(0x33FECE57);
const _stitchGoldBadgeBg = Color(0x66FECE57);
const _stitchGoldBadgeBorder = Color(0x4D775A00);
const _stitchOnSurface = Color(0xFF111C2D);
const _stitchOnSurfaceVariant = Color(0xFF45464D);
const _stitchOutline = Color(0xFF76767E);
const _stitchCardBorder = Color(0x4DC6C6CE);
const _stitchDivider = Color(0x33C6C6CE);
const _stitchSurfaceContainerLow = Color(0xFFF0F3FF);
const _stitchSurfaceContainer = Color(0xFFE7EEFF);
const _stitchSurfaceContainerHigh = Color(0xFFDEE8FF);
const _stitchSurfaceContainerHighest = Color(0x66D8E3FB);

const _stitchCardShadow = [
  BoxShadow(color: Color(0x0A1B2541), blurRadius: 20, offset: Offset(0, 4)),
];

Color _seasonPipColor(String seasonName) {
  final lower = seasonName.toLowerCase();
  if (lower.contains('vọng') ||
      lower.contains('chay') ||
      lower.contains('advent') ||
      lower.contains('lent')) {
    return AppColors.seasonAdventLent;
  }
  if (lower.contains('phục sinh') ||
      lower.contains('giáng sinh') ||
      lower.contains('easter') ||
      lower.contains('christmas')) {
    return const Color(0xFFC59B27);
  }
  if (lower.contains('thánh linh') ||
      lower.contains('hiện xuống') ||
      lower.contains('tử đạo') ||
      lower.contains('pentecost')) {
    return AppColors.seasonPentecostMartyrs;
  }
  return AppColors.seasonOrdinary;
}

/// Month calendar view aligned with the Stitch liturgical month template.
/// Allows choosing month and year, displays Sunday-to-Saturday columns,
/// distinguishes today/selected/out-of-month/activity days from real data,
/// and opens [LiturgicalDayDialog] when tapping a date.
class LiturgicalMonthCalendar extends ConsumerStatefulWidget {
  final List<LiturgicalEvent> events;
  final DateTime initialDate;
  final DateTime today;
  final bool eventsComplete;

  const LiturgicalMonthCalendar({
    super.key,
    this.events = const [],
    required this.initialDate,
    required this.today,
    required this.eventsComplete,
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

  RehearsalDateRange get _monthRange {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    return (
      fromDate: DateFormat('yyyy-MM-dd').format(firstDay),
      toDate: DateFormat('yyyy-MM-dd').format(lastDay),
    );
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
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
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
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
                        color: _stitchPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      foregroundColor: _stitchOutline,
                      hoverColor: _stitchSurfaceContainer,
                    ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            foregroundColor: _stitchPrimary,
                            hoverColor: _stitchSurfaceContainer,
                          ),
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
                              color: MemberChoirStyle.wine,
                            ),
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            foregroundColor: _stitchPrimary,
                            hoverColor: _stitchSurfaceContainer,
                          ),
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () =>
                              setDialogState(() => tempYear = tempYear + 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                            monthNum == tempMonth &&
                            tempYear == _currentMonth.year;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setDialogState(() => tempMonth = monthNum);
                            Navigator.of(ctx)
                                .pop(DateTime(tempYear, monthNum, 1));
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? MemberChoirStyle.wine
                                  : _stitchSurfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? MemberChoirStyle.wine
                                    : _stitchCardBorder,
                              ),
                            ),
                            child: Text(
                              'Tháng $monthNum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : _stitchOnSurface,
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
                  style: TextButton.styleFrom(
                    foregroundColor: MemberChoirStyle.wine,
                  ),
                  onPressed: () {
                    final now = widget.today;
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

    if (mounted && picked != null) {
      setState(() {
        _currentMonth = picked;
      });
    }
  }

  DateTime _parishDate(RehearsalSession rehearsal) =>
      rehearsal.date.toUtc().add(const Duration(hours: 7));

  bool _inCurrentMonth(DateTime date) =>
      date.year == _currentMonth.year && date.month == _currentMonth.month;

  void _onDayTapped(
    DateTime date,
    List<LiturgicalEvent> events,
    List<RehearsalSession> rehearsals,
  ) {
    setState(() => _selectedDate = date);
    LiturgicalDayDialog.show(
      context,
      date: date,
      events: events
          .where((event) => DateUtils.isSameDay(event.date, date))
          .toList(),
      rehearsals: rehearsals
          .where(
            (rehearsal) => DateUtils.isSameDay(_parishDate(rehearsal), date),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _monthRange;
    final rehearsalState = ref.watch(rehearsalsForRangeProvider(range));
    final events = widget.events
        .where((event) => _inCurrentMonth(event.date))
        .toList();
    final rehearsals =
        (rehearsalState.asData?.value ?? const <RehearsalSession>[])
            .where((rehearsal) => _inCurrentMonth(_parishDate(rehearsal)))
            .toList();
    final eventDays = events.map((event) => event.date.day).toSet();
    final rehearsalDays = rehearsals
        .map((rehearsal) => _parishDate(rehearsal).day)
        .toSet();
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final offset = _currentMonth.weekday % 7;
    final cells = ((offset + daysInMonth + 6) ~/ 7) * 7;
    final selected = _selectedDate;
    final hasSelected = selected != null && _inCurrentMonth(selected);
    final selectedEvents = hasSelected
        ? events
              .where((event) => DateUtils.isSameDay(event.date, selected))
              .toList()
        : const <LiturgicalEvent>[];
    final selectedRehearsals = hasSelected
        ? rehearsals
              .where(
                (rehearsal) =>
                    DateUtils.isSameDay(_parishDate(rehearsal), selected),
              )
              .toList()
        : const <RehearsalSession>[];
    final seasonSource =
        selectedEvents.any((event) => event.seasonName.trim().isNotEmpty)
        ? selectedEvents
        : events;
    final seasons = seasonSource
        .map((event) => event.seasonName.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final total = selectedEvents.length + selectedRehearsals.length;
    final complete =
        widget.eventsComplete &&
        !rehearsalState.isLoading &&
        !rehearsalState.hasError;

    final navIconStyle = IconButton.styleFrom(
      foregroundColor: _stitchPrimary,
      hoverColor: _stitchSurfaceContainer,
      highlightColor: _stitchSurfaceContainerHigh,
      minimumSize: const Size(38, 38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        // Month & season navigator card
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _stitchCardBorder),
            boxShadow: _stitchCardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Tháng trước',
                      onPressed: _previousMonth,
                      style: navIconStyle,
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    ),
                    Expanded(
                      child: Center(
                        child: TextButton(
                          onPressed: () => _pickMonthYear(context),
                          style:
                              TextButton.styleFrom(
                                foregroundColor: _stitchPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(0, 36),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ).copyWith(
                                overlayColor: const WidgetStatePropertyAll(
                                  _stitchSurfaceContainer,
                                ),
                              ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: [
                              Flexible(
                                child: Text(
                                  'Tháng ${_currentMonth.month}, ${_currentMonth.year}',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: _stitchPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 20,
                                color: _stitchOutline,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tháng sau',
                      onPressed: _nextMonth,
                      style: navIconStyle,
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    ),
                  ],
                ),
                if (seasons.isNotEmpty) ...[
                  const Divider(height: 1, color: _stitchDivider),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _stitchSurfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _stitchCardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _seasonPipColor(seasons.first),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              seasons.join(' · ').toUpperCase(),
                              style: AppTypography.labelSmall.copyWith(
                                color: _stitchPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Interactive liturgical month grid card
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _stitchCardBorder),
            boxShadow: _stitchCardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                const Row(
                  children: [
                    _WeekdayHeader('CN'),
                    _WeekdayHeader('Th2'),
                    _WeekdayHeader('Th3'),
                    _WeekdayHeader('Th4'),
                    _WeekdayHeader('Th5'),
                    _WeekdayHeader('Th6'),
                    _WeekdayHeader('Th7'),
                  ],
                ),
                if (rehearsalState.isLoading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: MemberChoirStyle.wine,
                    backgroundColor: _stitchSurfaceContainer,
                  ),
                if (rehearsalState.hasError)
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Không tải được lịch tập tháng này.'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: MemberChoirStyle.wine,
                        ),
                        onPressed: () =>
                            ref.invalidate(rehearsalsForRangeProvider(range)),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cells,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 4,
                    mainAxisExtent:
                        (MediaQuery.textScalerOf(context).scale(16) + 32).clamp(
                          48.0,
                          82.0,
                        ),
                  ),
                  itemBuilder: (context, index) {
                    final number = index - offset + 1;
                    final date = DateTime(
                      _currentMonth.year,
                      _currentMonth.month,
                      number,
                    );
                    if (number < 1 || number > daysInMonth) {
                      return ExcludeSemantics(
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: AppTypography.bodyMedium.copyWith(
                              color: _stitchOutline.withValues(alpha: 0.40),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }
                    return _CalendarDayCell(
                      date: date,
                      isToday: DateUtils.isSameDay(date, widget.today),
                      isSelected: DateUtils.isSameDay(date, selected),
                      hasEvent: eventDays.contains(number),
                      hasRehearsal: rehearsalDays.contains(number),
                      onTap: () => _onDayTapped(date, events, rehearsals),
                    );
                  },
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: _stitchCardBorder),
                const SizedBox(height: 2),
                const Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _CalendarLegend(
                      color: MemberChoirStyle.wine,
                      label: 'Lịch phục vụ',
                    ),
                    _CalendarLegend(color: _stitchSecondary, label: 'Lịch tập'),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Selected day detailed schedule
        if (hasSelected) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8,
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 20,
                color: MemberChoirStyle.wine,
              ),
              Expanded(
                child: Text(
                  'Lịch trình đã chọn · ${DateFormat('dd/MM/yyyy').format(selected)}',
                  style: AppTypography.titleMedium.copyWith(
                    color: _stitchPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (complete || total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: MemberChoirStyle.wine.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$total hoạt động',
                    style: AppTypography.labelSmall.copyWith(
                      color: MemberChoirStyle.wine,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (complete && total == 0)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _stitchCardBorder),
                boxShadow: _stitchCardShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Chưa có lịch phục vụ hoặc buổi tập được công bố cho ngày này.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: _stitchOnSurfaceVariant,
                  ),
                ),
              ),
            ),
          for (final event in selectedEvents)
            _MonthEventCard(
              event: event,
              onOpen: () => context.push(
                '/event-detail/${Uri.encodeComponent(event.id)}',
              ),
            ),
          for (final rehearsal in selectedRehearsals)
            _MonthRehearsalCard(
              rehearsal: rehearsal,
              onOpen: () => context.push(
                '/rehearsal/${Uri.encodeComponent(rehearsal.id)}',
              ),
            ),
        ],

        // Monthly liturgical activity summary
        if (complete && (events.isNotEmpty || rehearsals.isNotEmpty))
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _stitchSurfaceContainerLow,
                  _stitchSurfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _stitchCardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Row(
                    spacing: 6,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 15,
                        color: MemberChoirStyle.wine,
                      ),
                      Expanded(
                        child: Text(
                          'HOẠT ĐỘNG THÁNG ${_currentMonth.month}',
                          style: AppTypography.labelSmall.copyWith(
                            color: MemberChoirStyle.wine,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    spacing: 10,
                    children: [
                      Expanded(
                        child: _MonthlyStatTile(
                          count: '${events.length}',
                          label: 'CHƯƠNG TRÌNH PHỤC VỤ',
                          valueColor: MemberChoirStyle.wine,
                        ),
                      ),
                      Expanded(
                        child: _MonthlyStatTile(
                          count: '${rehearsals.length}',
                          label: 'BUỔI TẬP HÁT',
                          valueColor: _stitchSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthEventCard extends StatelessWidget {
  const _MonthEventCard({required this.event, required this.onOpen});

  final LiturgicalEvent event;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final badgeText = [
      'PHỤC VỤ',
      if (event.timeRange.isNotEmpty) event.timeRange,
    ].join(' • ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MemberChoirStyle.wine.withValues(alpha: 0.30),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F6D2636),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 6,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MemberChoirStyle.wine,
                        MemberChoirStyle.wine,
                        _stitchSecondaryContainer,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: MemberChoirStyle.wine,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 4,
                              children: [
                                const Icon(
                                  Icons.church_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                Flexible(
                                  child: Text(
                                    badgeText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (event.participationStatus !=
                              ParticipationStatus.unknown)
                            _EventStatusBadge(
                              status: event.participationStatus,
                            ),
                        ],
                      ),
                      Text(
                        event.title,
                        style: AppTypography.titleMedium.copyWith(
                          color: _stitchPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (event.location.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 17,
                              color: _stitchOutline,
                            ),
                            Expanded(
                              child: Text(
                                event.location,
                                style: AppTypography.bodySmall.copyWith(
                                  color: _stitchOnSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (event.assignedVocalPart.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 8,
                          children: [
                            const Icon(
                              Icons.record_voice_over_outlined,
                              size: 17,
                              color: _stitchOutline,
                            ),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Nhiệm vụ:',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: _stitchOnSurfaceVariant,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _stitchPrimaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      event.assignedVocalPart,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      const Divider(height: 1, color: _stitchCardBorder),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: onOpen,
                          style:
                              TextButton.styleFrom(
                                foregroundColor: MemberChoirStyle.wine,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ).copyWith(
                                foregroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(
                                            WidgetState.hovered,
                                          ) ||
                                          states.contains(
                                            WidgetState.pressed,
                                          )) {
                                        return _stitchWineHover;
                                      }
                                      return MemberChoirStyle.wine;
                                    }),
                              ),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          iconAlignment: IconAlignment.end,
                          label: const Text(
                            'Xem chi tiết',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
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
  }
}

class _MonthRehearsalCard extends StatelessWidget {
  const _MonthRehearsalCard({required this.rehearsal, required this.onOpen});

  final RehearsalSession rehearsal;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final badgeText = [
      'TẬP HÁT',
      if (rehearsal.timeRange.isNotEmpty) rehearsal.timeRange,
    ].join(' • ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stitchCardBorder),
        boxShadow: _stitchCardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _stitchGoldBadgeBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _stitchGoldBadgeBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 4,
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            size: 13,
                            color: _stitchOnSecondaryContainer,
                          ),
                          Flexible(
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: _stitchOnSecondaryContainer,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    rehearsal.title,
                    style: AppTypography.titleMedium.copyWith(
                      color: _stitchPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (rehearsal.location.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        const Icon(
                          Icons.meeting_room_outlined,
                          size: 17,
                          color: _stitchOutline,
                        ),
                        Expanded(
                          child: Text(
                            rehearsal.location,
                            style: AppTypography.bodySmall.copyWith(
                              color: _stitchOnSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (rehearsal.note?.trim().isNotEmpty == true)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        const Icon(
                          Icons.notes_rounded,
                          size: 17,
                          color: _stitchOutline,
                        ),
                        Expanded(
                          child: Text(
                            'Ghi chú: ${rehearsal.note!.trim()}',
                            style: AppTypography.bodySmall.copyWith(
                              color: _stitchOnSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const Divider(height: 1, color: _stitchDivider),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: onOpen,
                      style:
                          TextButton.styleFrom(
                            foregroundColor: _stitchPrimary,
                            backgroundColor: _stitchSurfaceContainer,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ).copyWith(
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.pressed)) {
                                return _stitchSurfaceContainerHigh;
                              }
                              return _stitchSurfaceContainer;
                            }),
                          ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      iconAlignment: IconAlignment.end,
                      label: const Text(
                        'Xem chi tiết',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventStatusBadge extends StatelessWidget {
  const _EventStatusBadge({required this.status});

  final ParticipationStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border, icon) = switch (status) {
      ParticipationStatus.confirmed => (
        const Color(0xFFECFDF5),
        const Color(0xFF065F46),
        const Color(0xFF6EE7B7),
        Icons.check_circle_rounded,
      ),
      ParticipationStatus.declined => (
        const Color(0xFFFEF2F2),
        const Color(0xFF991B1B),
        const Color(0xFFFCA5A5),
        Icons.cancel_rounded,
      ),
      ParticipationStatus.invited || ParticipationStatus.unsure => (
        const Color(0xFFFFFBEB),
        const Color(0xFF92400E),
        const Color(0xFFFCD34D),
        Icons.schedule_rounded,
      ),
      ParticipationStatus.unknown => (
        _stitchSurfaceContainerLow,
        _stitchOnSurfaceVariant,
        _stitchCardBorder,
        Icons.help_outline_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 13, color: fg),
          Flexible(
            child: Text(
              status.label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyStatTile extends StatelessWidget {
  const _MonthlyStatTile({
    required this.count,
    required this.label,
    required this.valueColor,
  });

  final String count;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.80),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _stitchDivider),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _stitchOutline,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Flexible(
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: _stitchOnSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _WeekdayHeader extends StatelessWidget {
  final String label;
  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final isSunday = label == 'CN';
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isSunday ? MemberChoirStyle.wine : _stitchOutline,
            fontSize: 12,
            fontWeight: isSunday ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.hasEvent,
    required this.hasRehearsal,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday, isSelected, hasEvent, hasRehearsal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSunday = date.weekday == DateTime.sunday;
    final fillColor = isSelected
        ? _stitchSelectedFill
        : isToday
        ? _stitchTodayFill
        : Colors.transparent;
    final borderColor = isSelected
        ? MemberChoirStyle.wine
        : isToday
        ? _stitchSecondaryContainer
        : Colors.transparent;
    final borderWidth = isSelected ? 2.0 : 1.0;
    final textColor = (isSelected || isToday || isSunday)
        ? MemberChoirStyle.wine
        : _stitchOnSurface;
    final fontWeight = isSelected
        ? FontWeight.w800
        : (isToday || isSunday)
        ? FontWeight.w700
        : FontWeight.w500;
    final rehearsalDotColor = (isSelected || isToday)
        ? _stitchSecondary
        : _stitchSecondaryContainer;

    final label = [
      DateFormat('dd/MM/yyyy').format(date),
      if (isToday) 'Hôm nay',
      if (hasEvent) 'Có lịch phục vụ',
      if (hasRehearsal) 'Có lịch tập',
    ].join(' · ');

    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x0D05102B),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: fillColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('calendar-month-day-${date.day}'),
            hoverColor: _stitchSurfaceContainerLow,
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: textColor,
                        fontSize: isSelected ? 15 : 14,
                        fontWeight: fontWeight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 3,
                    children: [
                      if (hasEvent)
                        const SizedBox(
                          width: 6,
                          height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: MemberChoirStyle.wine,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      if (hasRehearsal)
                        SizedBox(
                          width: 6,
                          height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: rehearsalDotColor,
                              shape: BoxShape.circle,
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
  }
}
