import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/widgets/harmonia_logo.dart';
import '../../../app/widgets/member_choir_visuals.dart';
import '../../../app/widgets/stitch_entrance.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/error_messages.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';
import 'calendar_timeline_cards.dart';
import 'liturgical_month_calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

typedef _TimelineEntry = ({
  DateTime start,
  LiturgicalEvent? event,
  RehearsalSession? rehearsal,
});

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const _stitchBorder = Color(0xFFE6E1D8);
  static const _stitchTextDark = Color(0xFF201C21);
  static const _stitchTextMuted = Color(0xFF76767E);
  static const _stitchGold = Color(0xFFFECE57);
  late DateTime _selectedDay;
  late DateTime _weekStart;
  int _tab = 0;
  int _monthRevision = 0;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _selectToday();
  }

  void _selectToday() {
    _selectedDay = _today();
    _weekStart = _monday(_selectedDay);
  }

  // Event DateOnly/TimeOnly uses parish time; rehearsal timestamps are instants.
  DateTime _parishTime(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 7));

  DateTime _today() => DateUtils.dateOnly(_parishTime(DateTime.now()));

  DateTime _monday(DateTime date) =>
      DateTime(date.year, date.month, date.day - date.weekday + 1);

  DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  RehearsalDateRange get _weekRange => (
    fromDate: _dateKey(_weekStart),
    toDate: _dateKey(_addDays(_weekStart, 6)),
  );

  List<_TimelineEntry> _dayTimeline(
    List<LiturgicalEvent> events,
    List<RehearsalSession> rehearsals,
  ) =>
      [
        for (final event in events)
          if (DateUtils.isSameDay(DateUtils.dateOnly(event.date), _selectedDay))
            (start: _eventStart(event), event: event, rehearsal: null),
        for (final rehearsal in rehearsals)
          if (DateUtils.isSameDay(_parishTime(rehearsal.date), _selectedDay))
            (
              start: _parishTime(rehearsal.date),
              event: null,
              rehearsal: rehearsal,
            ),
      ]..sort((a, b) {
        final timeOrder = a.start.compareTo(b.start);
        if (timeOrder != 0) return timeOrder;
        final aId = a.event?.id ?? a.rehearsal!.id;
        final bId = b.event?.id ?? b.rehearsal!.id;
        return aId.compareTo(bId);
      });

  DateTime _eventStart(LiturgicalEvent event) {
    // Match the UTC-marked parish wall clock returned by _parishTime.
    final time = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(event.timeRange);
    return DateTime.utc(
      event.date.year,
      event.date.month,
      event.date.day,
      time == null ? 0 : int.parse(time.group(1)!),
      time == null ? 0 : int.parse(time.group(2)!),
    );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final isMonth = _tab == 1;
    if (isMonth) {
      ref.invalidate(rehearsalsForRangeProvider);
    } else {
      ref.invalidate(rehearsalsForRangeProvider(_weekRange));
    }
    ref.invalidate(calendarNotifierProvider);
    ref.invalidate(publicAppSettingsProvider);
    ref.invalidate(rehearsalDetailProvider);
    ref.invalidate(eventDetailProvider);
    try {
      await Future.wait([
        if (!isMonth) ref.read(rehearsalsForRangeProvider(_weekRange).future),
        ref.read(calendarNotifierProvider.notifier).loadEvents(),
      ]);
    } catch (_) {
      // Every source retains its own error and retry action.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsState = ref.watch(calendarNotifierProvider);
    final rehearsalRange = _weekRange;
    final rehearsalsState = _tab == 0
        ? ref.watch(rehearsalsForRangeProvider(rehearsalRange))
        : const AsyncData(<RehearsalSession>[]);
    final settings = ref.watch(publicAppSettingsProvider).asData?.value;
    final captionLabel = [
      settings?.choirName.trim() ?? '',
      settings?.parishName.trim() ?? '',
    ].where((name) => name.isNotEmpty).join(' · ');
    final events = eventsState.asData?.value ?? const <LiturgicalEvent>[];
    final rehearsals =
        rehearsalsState.asData?.value ?? const <RehearsalSession>[];
    final timelineItems = _dayTimeline(events, rehearsals);
    final today = _today();
    final isPastDay = _selectedDay.isBefore(today);
    final loading = eventsState.isLoading || rehearsalsState.isLoading;
    final incomplete = eventsState.hasError || rehearsalsState.hasError;

    final isMonthTab = _tab == 1;
    final weekEnd = _addDays(_weekStart, 6);
    final weekEvents = [
      for (final event in events)
        if (!DateUtils.dateOnly(event.date).isBefore(_weekStart) &&
            !DateUtils.dateOnly(event.date).isAfter(weekEnd))
          event,
    ];
    final weekRehearsals = [
      for (final rehearsal in rehearsals)
        if (!DateUtils.dateOnly(_parishTime(rehearsal.date))
                .isBefore(_weekStart) &&
            !DateUtils.dateOnly(_parishTime(rehearsal.date)).isAfter(weekEnd))
          rehearsal,
    ];
    final selectedDayEvents = [
      for (final event in weekEvents)
        if (DateUtils.isSameDay(DateUtils.dateOnly(event.date), _selectedDay))
          event,
    ];
    final weekSeason = isMonthTab
        ? ''
        : _resolveWeekSeason(ref, selectedDayEvents, weekEvents);

    return Theme(
      data: MemberChoirStyle.theme(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: MemberChoirStyle.wine,
          appBar: null,
          body: SafeArea(
            top: true,
            bottom: false,
            child: ColoredBox(
              color: isMonthTab
                  ? const Color(0xFFFAF8F5)
                  : MemberChoirStyle.paper,
              child: RefreshIndicator(
                color: MemberChoirStyle.accent,
                onRefresh: _refresh,
                child: ListView(
                  key: ValueKey((
                    _dateKey(_selectedDay),
                    _tab,
                    isMonthTab ? _monthRevision : 0,
                  )),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _calendarHeader(captionLabel, isMonthTab: isMonthTab),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!isMonthTab) ...[
                            _weekNavigator(today, weekSeason),
                            const SizedBox(height: 14),
                            _daySelector(today, events, rehearsals),
                            const SizedBox(height: 18),
                            _selectedDayHeader(timelineItems.length),
                            const SizedBox(height: 12),
                            if (loading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: LinearProgressIndicator(
                                  minHeight: 2,
                                  color: MemberChoirStyle.wine,
                                  backgroundColor: Color(0xFFE7EEFF),
                                ),
                              ),
                            if (eventsState.hasError)
                              _sourceError(
                                eventsState.error!,
                                'Thử lại lịch phục vụ',
                                () => ref
                                    .read(calendarNotifierProvider.notifier)
                                    .loadEvents(),
                              ),
                            if (rehearsalsState.hasError)
                              _sourceError(
                                rehearsalsState.error!,
                                'Thử lại lịch tập',
                                () => ref.invalidate(
                                  rehearsalsForRangeProvider(rehearsalRange),
                                ),
                              ),
                            if (isPastDay)
                              _notice(
                                'Chưa có lịch phục vụ hoặc lịch tập trong ngày đã qua.',
                              )
                            else if (timelineItems.isEmpty &&
                                !loading &&
                                !incomplete)
                              _notice(
                                'Chưa có lịch phục vụ hoặc lịch tập trong ngày ${DateFormat('dd/MM/yyyy').format(_selectedDay)}.',
                              ),
                            if (timelineItems.isNotEmpty)
                              for (var i = 0; i < timelineItems.length; i++)
                                _timelineRow(
                                  timelineItems[i],
                                  isLast: i == timelineItems.length - 1,
                                ),
                            if (!loading &&
                                !incomplete &&
                                (weekEvents.isNotEmpty ||
                                    weekRehearsals.isNotEmpty))
                              _weekSummaryCard(
                                eventCount: weekEvents.length,
                                rehearsalCount: weekRehearsals.length,
                              ),
                          ] else ...[
                            if (eventsState.isLoading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                            if (eventsState.hasError)
                              _sourceError(
                                eventsState.error!,
                                'Thử lại lịch phục vụ',
                                () => ref
                                    .read(calendarNotifierProvider.notifier)
                                    .loadEvents(),
                              ),
                            LiturgicalMonthCalendar(
                              initialDate: _selectedDay,
                              today: today,
                              events: events,
                              eventsComplete:
                                  !eventsState.isLoading &&
                                  !eventsState.hasError,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveWeekSeason(
    WidgetRef ref,
    List<LiturgicalEvent> selectedDayEvents,
    List<LiturgicalEvent> weekEvents,
  ) {
    for (final event in selectedDayEvents) {
      final season = event.seasonName.trim();
      if (season.isNotEmpty) return season;
      final detailSeason =
          ref
              .watch(eventDetailProvider(event.id))
              .asData
              ?.value
              .event
              .seasonName
              .trim() ??
          '';
      if (detailSeason.isNotEmpty) return detailSeason;
    }
    for (final event in weekEvents) {
      final season = event.seasonName.trim();
      if (season.isNotEmpty) return season;
    }
    return '';
  }

  Widget _calendarHeader(
    String captionLabel, {
    required bool isMonthTab,
  }) => DecoratedBox(
    decoration: const BoxDecoration(
      color: MemberChoirStyle.wine,
      boxShadow: [
        BoxShadow(
          color: Color(0x2405102B),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const HarmoniaLogo(size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (captionLabel.isNotEmpty ? captionLabel : 'Harmonia')
                          .toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.80),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      isMonthTab ? 'Lịch Tháng Phụng Vụ' : 'Lịch Tuần Phụng Vụ',
                      style: AppTypography.titleLarge.copyWith(
                        fontFamily: MemberChoirStyle.displayFont,
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Hôm nay',
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _selectToday();
                    if (isMonthTab) _monthRevision++;
                  }),
                  style:
                      OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        shape: const StadiumBorder(),
                      ).copyWith(
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.pressed)) {
                            return Colors.white.withValues(alpha: 0.25);
                          }
                          return Colors.white.withValues(alpha: 0.15);
                        }),
                      ),
                  child: const Text(
                    'Hôm nay',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lịch lễ, phiên tập dượt & trực hát cộng đoàn',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.80),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          StitchEntrance(distance: 4, child: _tabs()),
        ],
      ),
    ),
  );

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: Row(
      children: [
        for (final (index, label) in [(0, 'Lịch tuần'), (1, 'Lịch tháng')])
          Expanded(
            child: Semantics(
              selected: _tab == index,
              child: TextButton(
                onPressed: () => setState(() => _tab = index),
                style:
                    TextButton.styleFrom(
                      minimumSize: const Size(44, 38),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: _tab == index
                          ? Colors.white
                          : Colors.transparent,
                      foregroundColor: _tab == index
                          ? MemberChoirStyle.wine
                          : Colors.white.withValues(alpha: 0.85),
                      shape: const StadiumBorder(),
                    ).copyWith(
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (_tab == index) return MemberChoirStyle.wine;
                        if (states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.pressed)) {
                          return Colors.white;
                        }
                        return Colors.white.withValues(alpha: 0.85);
                      }),
                      iconColor: WidgetStateProperty.resolveWith((states) {
                        if (_tab == index) return MemberChoirStyle.wine;
                        if (states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.pressed)) {
                          return Colors.white;
                        }
                        return Colors.white.withValues(alpha: 0.85);
                      }),
                      overlayColor: WidgetStateProperty.resolveWith((states) {
                        if (_tab == index) {
                          return MemberChoirStyle.wine.withValues(alpha: 0.06);
                        }
                        return Colors.white.withValues(alpha: 0.12);
                      }),
                    ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 6,
                  children: [
                    Icon(
                      index == 0
                          ? Icons.view_week_outlined
                          : Icons.calendar_month_outlined,
                      size: 16,
                    ),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _tab == index
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _weekNavigator(DateTime today, String weekSeason) {
    final navStyle = IconButton.styleFrom(
      foregroundColor: const Color(0xFF111C2D),
      disabledForegroundColor: const Color(0x6676767E),
      hoverColor: const Color(0xFFF0F3FF),
      highlightColor: const Color(0xFFE7EEFF),
      minimumSize: const Size(36, 36),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x66C6C6CE)),
      ),
    );
    final seasonColor = calendarSeasonColor(weekSeason);
    return _panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Tuần trước',
                onPressed: _weekStart.isAfter(_monday(today))
                    ? () => _moveWeek(-7)
                    : null,
                style: navStyle,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'KHOẢNG THỜI GIAN PHỤNG VỤ',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSmall.copyWith(
                          color: _stitchTextMuted,
                          fontSize: 10,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd/MM/yyyy').format(_weekStart)} – ${DateFormat('dd/MM/yyyy').format(_addDays(_weekStart, 6))}',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelLarge.copyWith(
                          color: _stitchTextDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tuần sau',
                onPressed: () => _moveWeek(7),
                style: navStyle,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
          ),
          if (weekSeason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: seasonColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: seasonColor.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: seasonColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        weekSeason.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSmall.copyWith(
                          color: seasonColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
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
    );
  }

  void _moveWeek(int days) => setState(() {
    _weekStart = _addDays(_weekStart, days);
    _selectedDay = _addDays(_selectedDay, days);
  });

  Widget _daySelector(
    DateTime today,
    List<LiturgicalEvent> events,
    List<RehearsalSession> rehearsals,
  ) => Row(
    spacing: 5,
    children: [
      for (var i = 0; i < 7; i++)
        Expanded(
          child: _dayButton(_addDays(_weekStart, i), today, events, rehearsals),
        ),
    ],
  );

  Widget _dayButton(
    DateTime day,
    DateTime today,
    List<LiturgicalEvent> events,
    List<RehearsalSession> rehearsals,
  ) {
    final selected = DateUtils.isSameDay(day, _selectedDay);
    final isToday = DateUtils.isSameDay(day, today);
    final isSunday = day.weekday == DateTime.sunday;
    final hasActivity =
        events.any(
          (event) => DateUtils.isSameDay(DateUtils.dateOnly(event.date), day),
        ) ||
        rehearsals.any(
          (rehearsal) => DateUtils.isSameDay(_parishTime(rehearsal.date), day),
        );
    final dayCode = const [
      'T2',
      'T3',
      'T4',
      'T5',
      'T6',
      'T7',
      'CN',
    ][day.weekday - 1];
    final labelColor = selected
        ? Colors.white.withValues(alpha: 0.80)
        : isSunday
        ? MemberChoirStyle.accent
        : _stitchTextMuted;
    final numberColor = selected
        ? Colors.white
        : isSunday
        ? MemberChoirStyle.accent
        : const Color(0xFF111C2D);
    final dotColor = hasActivity
        ? (selected ? _stitchGold : MemberChoirStyle.accent)
        : Colors.transparent;

    return Semantics(
      label: 'Chọn ngày ${DateFormat('dd/MM/yyyy').format(day)}',
      selected: selected,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x408E3B4B),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: selected ? MemberChoirStyle.accent : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected
                  ? MemberChoirStyle.accent
                  : isToday
                  ? _stitchGold
                  : _stitchBorder,
              width: selected || isToday ? 1.5 : 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('calendar-day-${_dateKey(day)}'),
            hoverColor: selected
                ? MemberChoirStyle.wine
                : const Color(0xFFF0F3FF),
            onTap: () => setState(() => _selectedDay = day),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayCode,
                    maxLines: 1,
                    style: AppTypography.labelSmall.copyWith(
                      color: labelColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${day.day}',
                      style: AppTypography.labelLarge.copyWith(
                        color: numberColor,
                        fontSize: 14,
                        fontWeight: (selected || isSunday || isToday)
                            ? FontWeight.w700
                            : FontWeight.w600,
                        decoration: isToday && !selected
                            ? TextDecoration.underline
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: selected ? 6 : 5,
                    height: selected ? 6 : 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
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

  Widget _selectedDayHeader(int count) {
    final weekdayName = const [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ][_selectedDay.weekday - 1];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 8,
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 18,
          color: MemberChoirStyle.accent,
        ),
        Expanded(
          child: Text(
            '$weekdayName, ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
            style: AppTypography.titleMedium.copyWith(
              color: _stitchTextDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: MemberChoirStyle.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: MemberChoirStyle.accent.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: MemberChoirStyle.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$count hoạt động',
                  style: AppTypography.labelSmall.copyWith(
                    color: MemberChoirStyle.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String? _eventPeriodLabel(LiturgicalEvent event, DateTime start) {
    if (!RegExp(r'\d{1,2}:\d{2}').hasMatch(event.timeRange)) return null;
    if (start.hour < 12) return 'Sáng';
    if (start.hour < 18) return 'Chiều';
    return 'Tối';
  }

  Widget _timelineRow(_TimelineEntry item, {required bool isLast}) {
    final rehearsal = item.rehearsal;
    final event = item.event;
    final startLabel =
        event != null && !RegExp(r'\d{1,2}:\d{2}').hasMatch(event.timeRange)
        ? '—'
        : DateFormat('HH:mm').format(item.start);
    final subTimeLabel = rehearsal != null
        ? (rehearsal.endTime != null
              ? DateFormat('HH:mm').format(_parishTime(rehearsal.endTime!))
              : null)
        : _eventPeriodLabel(event!, item.start);

    return Padding(
      key: ValueKey(
        event == null
            ? 'timeline-rehearsal-${rehearsal!.id}'
            : 'timeline-event-${event.id}',
      ),
      padding: EdgeInsets.only(bottom: isLast ? 4 : 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    startLabel,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelLarge.copyWith(
                      color: _stitchTextDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subTimeLabel != null)
                    Text(
                      subTimeLabel,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall.copyWith(
                        color: _stitchTextMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: event == null
                          ? _stitchGold
                          : MemberChoirStyle.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MemberChoirStyle.paper,
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F05102B),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      event == null
                          ? Icons.queue_music_rounded
                          : Icons.church_rounded,
                      size: 13,
                      color: event == null ? _stitchTextDark : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isLast
                              ? const [Color(0x80C6C6CE), Colors.transparent]
                              : const [
                                  MemberChoirStyle.accent,
                                  Color(0xFFC6C6CE),
                                  Color(0x4D8E3B4B),
                                ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: event == null
                    ? CalendarRehearsalCard(
                        rehearsal: rehearsal!,
                        attendanceOnly: false,
                      )
                    : CalendarEventCard(event: event),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekSummaryCard({
    required int eventCount,
    required int rehearsalCount,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: _panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: 6,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 17,
                color: MemberChoirStyle.accent,
              ),
              Expanded(
                child: Text(
                  'Hoạt động tuần này',
                  style: AppTypography.labelLarge.copyWith(
                    color: _stitchTextDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: Color(0x33C6C6CE)),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: _weekStatBox(
                  value: '$eventCount',
                  label: 'Chương trình phục vụ',
                  valueColor: MemberChoirStyle.accent,
                ),
              ),
              Expanded(
                child: _weekStatBox(
                  value: '$rehearsalCount',
                  label: 'Buổi tập hát',
                  valueColor: const Color(0xFF775A00),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _weekStatBox({
    required String value,
    required String label,
    required Color valueColor,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFAF8F5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x99E6E1D8)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.titleLarge.copyWith(
            color: valueColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.labelSmall.copyWith(
            color: _stitchTextMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _panel({required Widget child, required EdgeInsetsGeometry padding}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _stitchBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A1B2541),
              blurRadius: 20,
              spreadRadius: -2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _notice(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: _panel(
      padding: const EdgeInsets.all(20),
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(color: _stitchTextMuted),
        textAlign: TextAlign.center,
      ),
    ),
  );

  Widget _sourceError(Object error, String label, VoidCallback retry) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                ErrorMessages.forException(error),
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: retry,
                style: TextButton.styleFrom(
                  foregroundColor: MemberChoirStyle.wine,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      );
}
