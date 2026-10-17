import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/error_messages.dart';
import '../../music/data/music_repository.dart';
import '../data/calendar_dto.dart';
import '../data/calendar_repository.dart';
import '../data/liturgical_models.dart';
import 'calendar_timeline_cards.dart';

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
  static const _softSurface = Color(0xFFF1F1F3);
  late DateTime _selectedDay;
  late DateTime _weekStart;
  int _tab = 0;
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

  LiturgicalDateRange get _range => (
    fromDate: _dateKey(_weekStart),
    toDate: _dateKey(_addDays(_weekStart, 6)),
  );

  DateTime _eventStart(LiturgicalEvent event) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(event.timeRange);
    final hour = int.tryParse(match?.group(1) ?? '');
    final minute = int.tryParse(match?.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      // Unknown times sort after the timed activities of the same day.
      return DateTime.utc(
        event.date.year,
        event.date.month,
        event.date.day + 1,
      ).subtract(const Duration(hours: 7));
    }
    return DateTime.utc(
      event.date.year,
      event.date.month,
      event.date.day,
      hour,
      minute,
    ).subtract(const Duration(hours: 7));
  }

  List<_TimelineEntry> _timeline(
    List<LiturgicalEvent> events,
    List<RehearsalSession> rehearsals,
  ) =>
      [
        for (final event in events)
          if (DateUtils.isSameDay(event.date, _selectedDay))
            (start: _eventStart(event), event: event, rehearsal: null),
        for (final rehearsal in rehearsals)
          if (DateUtils.isSameDay(_parishTime(rehearsal.date), _selectedDay))
            (start: rehearsal.date.toUtc(), event: null, rehearsal: rehearsal),
      ]..sort((a, b) {
        final timeOrder = a.start.compareTo(b.start);
        if (timeOrder != 0) return timeOrder;
        return (a.event?.id ?? a.rehearsal!.id).compareTo(
          b.event?.id ?? b.rehearsal!.id,
        );
      });

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    ref.invalidate(rehearsalsProvider);
    ref.invalidate(liturgicalDaysProvider(_range));
    ref.invalidate(publicAppSettingsProvider);
    ref.invalidate(eventDetailProvider);
    ref.invalidate(rehearsalDetailProvider);
    ref.invalidate(eventApprovedSongListProvider);
    try {
      await Future.wait([
        ref.read(calendarNotifierProvider.notifier).loadEvents(),
        ref.read(rehearsalsProvider.future),
        ref.read(liturgicalDaysProvider(_range).future),
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
    final rehearsalsState = ref.watch(rehearsalsProvider);
    final daysState = ref.watch(liturgicalDaysProvider(_range));
    final settings = ref.watch(publicAppSettingsProvider).asData?.value;
    final choirName = settings?.choirName.trim();
    final events = eventsState.asData?.value ?? const <LiturgicalEvent>[];
    final rehearsals =
        rehearsalsState.asData?.value ?? const <RehearsalSession>[];
    final items = _timeline(events, rehearsals);
    final today = _today();
    final isPastDay = _selectedDay.isBefore(today);
    final loading = eventsState.isLoading || rehearsalsState.isLoading;
    final incomplete = eventsState.hasError || rehearsalsState.hasError;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        titleSpacing: 16,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: _softSurface,
              child: Icon(
                Icons.music_note_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    choirName != null && choirName.isNotEmpty
                        ? choirName
                        : 'Harmonia Choir',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  Text('Lịch của tôi', style: AppTypography.headlineSmall),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới lịch',
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () => context.go('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView(
            key: ValueKey('calendar-${_dateKey(_selectedDay)}-$_tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _tabs(),
              const SizedBox(height: 16),
              _weekNavigator(today),
              const SizedBox(height: 16),
              _daySelector(today, events, rehearsals),
              const SizedBox(height: 16),
              _daySummary(daysState, items.length, loading, incomplete),
              const SizedBox(height: 20),
              if (isPastDay)
                _notice(
                  'Chưa hỗ trợ xem đầy đủ lịch đã qua. Bạn vẫn có thể xem thông tin ngày phụng vụ.',
                ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
              if (eventsState.hasError)
                _sourceError(
                  eventsState.error!,
                  'Thử lại lịch lễ',
                  () =>
                      ref.read(calendarNotifierProvider.notifier).loadEvents(),
                ),
              if (rehearsalsState.hasError)
                _sourceError(
                  rehearsalsState.error!,
                  'Thử lại lịch tập',
                  () => ref.invalidate(rehearsalsProvider),
                ),
              if (items.isEmpty && !loading && !incomplete && !isPastDay)
                _notice(
                  'Chưa có lịch trong ngày ${DateFormat('dd/MM/yyyy').format(_selectedDay)}.',
                ),
              for (final item in items) _timelineRow(item),
              if (_tab == 0)
                for (final item in items)
                  if (item.event != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      child: CalendarApprovedSongs(event: item.event!),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: _softSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        for (final (index, label) in [(0, 'Lịch tuần'), (1, 'Điểm danh')])
          Expanded(
            child: Semantics(
              selected: _tab == index,
              child: TextButton(
                onPressed: () => setState(() => _tab = index),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: _tab == index
                      ? AppColors.surface
                      : Colors.transparent,
                  foregroundColor: _tab == index
                      ? AppColors.primary
                      : AppColors.muted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _weekNavigator(DateTime today) => _panel(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Tuần trước',
          onPressed: _weekStart.isAfter(_monday(today))
              ? () => _moveWeek(-7)
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            '${DateFormat('dd/MM/yyyy').format(_weekStart)} – ${DateFormat('dd/MM/yyyy').format(_addDays(_weekStart, 6))}',
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Tuần sau',
          onPressed: () => _moveWeek(7),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        TextButton(
          onPressed: () => setState(_selectToday),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.body,
            backgroundColor: _softSurface,
            minimumSize: const Size(60, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: const Text('Hôm nay', textAlign: TextAlign.center),
        ),
        const SizedBox(width: 4),
      ],
    ),
  );

  void _moveWeek(int days) => setState(() {
    _weekStart = _addDays(_weekStart, days);
    _selectedDay = _addDays(_selectedDay, days);
  });

  Widget _daySelector(
    DateTime today,
    List<LiturgicalEvent> events,
    List<RehearsalSession> rehearsals,
  ) => _panel(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _dayButton(
              _addDays(_weekStart, i),
              today,
              events,
              rehearsals,
            ),
          ),
      ],
    ),
  );

  Widget _dayButton(
    DateTime day,
    DateTime today,
    List<LiturgicalEvent> events,
    List<RehearsalSession> rehearsals,
  ) {
    final selected = DateUtils.isSameDay(day, _selectedDay);
    final hasActivity =
        events.any((event) => DateUtils.isSameDay(event.date, day)) ||
        rehearsals.any(
          (rehearsal) => DateUtils.isSameDay(_parishTime(rehearsal.date), day),
        );
    final foreground = selected ? AppColors.onPrimary : AppColors.onSurface;
    return Semantics(
      label: 'Chọn ngày ${DateFormat('dd/MM/yyyy').format(day)}',
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('calendar-day-${_dateKey(day)}'),
          onTap: () => setState(() => _selectedDay = day),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][day.weekday -
                      1],
                  style: AppTypography.labelSmall.copyWith(
                    color: selected ? AppColors.onPrimary : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${day.day}',
                  style: AppTypography.titleMedium.copyWith(
                    color: foreground,
                    decoration: DateUtils.isSameDay(day, today) && !selected
                        ? TextDecoration.underline
                        : null,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasActivity
                        ? (selected ? AppColors.onPrimary : AppColors.primary)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _daySummary(
    AsyncValue<List<LiturgicalDay>> state,
    int count,
    bool loading,
    bool incomplete,
  ) {
    final day = state.asData?.value
        .where((day) => DateUtils.isSameDay(day.date, _selectedDay))
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.church_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  day?.celebrationName ??
                      (state.isLoading
                          ? 'Đang tải ngày phụng vụ…'
                          : state.hasError
                          ? 'Chưa tải được ngày phụng vụ'
                          : 'Chưa có thông tin ngày phụng vụ'),
                  style: AppTypography.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _selectedDay.isBefore(_today())
                ? 'Lịch đã qua chưa đầy đủ'
                : loading
                ? 'Đang tải lịch…'
                : incomplete
                ? 'Lịch chưa được tải đầy đủ'
                : '$count hoạt động • Giờ Việt Nam',
            style: AppTypography.bodySmall.copyWith(color: AppColors.muted),
          ),
          if (state.hasError) ...[
            Text(
              ErrorMessages.forException(state.error!),
              style: AppTypography.bodySmall,
            ),
            TextButton(
              onPressed: () => ref.invalidate(liturgicalDaysProvider(_range)),
              child: const Text('Thử lại ngày phụng vụ'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timelineRow(_TimelineEntry item) {
    final event = item.event;
    final rehearsal = item.rehearsal;
    final times = event != null
        ? RegExp(r'\d{1,2}:\d{2}')
              .allMatches(event.timeRange)
              .map((match) => match.group(0)!)
              .toList()
        : [
            DateFormat('HH:mm').format(_parishTime(rehearsal!.date)),
            if (rehearsal.endTime != null)
              DateFormat('HH:mm').format(_parishTime(rehearsal.endTime!)),
          ];
    return Padding(
      key: ValueKey(
        event != null
            ? 'timeline-event-${event.id}'
            : 'timeline-rehearsal-${rehearsal!.id}',
      ),
      padding: const EdgeInsets.only(bottom: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    times.isNotEmpty ? times.first : '—',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (rehearsal != null && times.length > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      times[1],
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 14,
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Expanded(
                    child: VerticalDivider(
                      color: AppColors.border,
                      thickness: 2,
                      width: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: event != null
                  ? CalendarEventCard(event: event, attendanceOnly: _tab == 1)
                  : CalendarRehearsalCard(
                      rehearsal: rehearsal!,
                      attendanceOnly: _tab == 1,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child, required EdgeInsetsGeometry padding}) =>
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

  Widget _notice(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: _panel(
      padding: const EdgeInsets.all(20),
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
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
              TextButton(onPressed: retry, child: Text(label)),
            ],
          ),
        ),
      );
}
