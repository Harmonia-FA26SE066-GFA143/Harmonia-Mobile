import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/session/session_manager.dart';
import '../data/staff_operations_api.dart';
import '../data/staff_workspace_repository.dart';
import 'staff_ops_widgets.dart';

const _directorReports = [
  (
    type: 'RehearsalAttendance',
    path: 'rehearsal-attendance',
    label: 'Điểm danh tập hát',
  ),
  (type: 'Participation', path: 'participation', label: 'Tham gia phụng vụ'),
  (
    type: 'AssignmentCompletion',
    path: 'assignment-completion',
    label: 'Hoàn thành bài tập',
  ),
  (type: 'Trend', path: 'activity-trend', label: 'Xu hướng theo tháng'),
];
const _priestReports = [
  (type: 'ServiceHistory', path: 'service-history', label: 'Lịch sử phục vụ'),
  (type: 'SongUsage', path: 'song-usage', label: 'Tần suất sử dụng bài hát'),
];
typedef _Query = ({
  String type,
  String path,
  int page,
  DateTimeRange dates,
  String? choir,
});

Map<String, dynamic> _filters(_Query query) {
  final format = DateFormat('yyyy-MM-dd');
  return {
    'fromDate': format.format(query.dates.start),
    'toDate': format.format(query.dates.end),
    'choirId': ?query.choir,
  };
}

final _report = FutureProvider.autoDispose.family(
  (ref, _Query query) => (
    ref.watch(staffOperationsApiProvider).columns(query.type),
    ref
        .watch(staffOperationsApiProvider)
        .report(query.path, query.page, _filters(query)),
  ).wait,
);
final _trend = FutureProvider.autoDispose.family(
  (ref, _Query query) =>
      ref.watch(staffOperationsApiProvider).trend(_filters(query)),
);
final _choirs = FutureProvider.autoDispose(
  (ref) => ref.watch(staffWorkspaceRepositoryProvider).choirs(),
);

class StaffReportsScreen extends ConsumerStatefulWidget {
  const StaffReportsScreen({super.key, required this.role});
  final MobileRole role;
  @override
  ConsumerState<StaffReportsScreen> createState() => _StaffReportsScreenState();
}

class _StaffReportsScreenState extends ConsumerState<StaffReportsScreen>
    with OpsActions<StaffReportsScreen> {
  late final _today = vietnamClock(DateTime.now());
  late var _dates = DateTimeRange(
    start: DateTime(_today.year, _today.month - 2),
    end: DateTime(_today.year, _today.month, _today.day),
  );
  String? _type;
  String? _choir;
  int _page = 1;

  String _rate(double? fraction) =>
      fraction == null ? '—' : '${(fraction * 100).toStringAsFixed(1)}%';

  String _value(ReportColumn column, Object? value) {
    if (value == null) return '—';
    if (value is num && column.key.endsWith('Rate')) {
      return _rate(value.toDouble());
    }
    if (value is num) return NumberFormat.decimalPattern('vi').format(value);
    if (value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      final date = DateTime.tryParse(value);
      if (date != null) return opsDay(date);
    }
    return value.toString();
  }

  Future<void> _chooseDates() async {
    final dates = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_today.year - 10),
      lastDate: DateTime(_today.year + 2),
      initialDateRange: _dates,
    );
    if (dates != null && mounted) {
      if (_type == 'Trend' && dates.duration.inDays > 1095) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chọn khoảng thời gian tối đa 3 năm cho báo cáo xu hướng.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _dates = dates;
        _page = 1;
      });
    }
  }

  Future<void> _export(_Query query) async {
    final api = ref.read(staffOperationsApiProvider);
    if (await runAction(() async {
          final csv = await api.exportCsv(query.type, _filters(query));
          if (mounted) await Clipboard.setData(ClipboardData(text: csv));
        }) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép nội dung CSV.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final director = widget.role == MobileRole.choirDirector;
    final choices = director ? _directorReports : _priestReports;
    final report =
        choices.where((row) => row.type == _type).firstOrNull ?? choices.first;
    final query = (
      type: report.type,
      path: report.path,
      page: _page,
      dates: _dates,
      choir: _choir,
    );
    return OpsPage(
      title: 'Báo cáo',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                actionState,
                OpsChoiceField(
                  label: 'Loại báo cáo',
                  value: report.type,
                  options: [
                    for (final choice in choices)
                      (id: choice.type, name: choice.label),
                  ],
                  onChanged: busy
                      ? null
                      : (type) => setState(() {
                          _type = type;
                          _page = 1;
                          if (type == 'Trend' &&
                              _dates.duration.inDays > 1095) {
                            _dates = DateTimeRange(
                              start: DateTime(_today.year, _today.month - 2),
                              end: DateTime(
                                _today.year,
                                _today.month,
                                _today.day,
                              ),
                            );
                          }
                        }),
                ),
                if (director)
                  ref
                      .watch(_choirs)
                      .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => TextButton(
                          onPressed: () => ref.invalidate(_choirs),
                          child: const Text('Tải lại bộ lọc ca đoàn'),
                        ),
                        data: (choirs) => OpsChoiceField(
                          label: 'Ca đoàn',
                          value: _choir,
                          optional: true,
                          emptyLabel: 'Tất cả ca đoàn của tôi',
                          options: [
                            for (final choir in choirs)
                              (id: choir.id, name: choir.name),
                          ],
                          onChanged: busy
                              ? null
                              : (choir) => setState(() {
                                  _choir = choir;
                                  _page = 1;
                                }),
                        ),
                      ),
                OutlinedButton.icon(
                  onPressed: busy ? null : _chooseDates,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    '${opsDay(_dates.start)} – ${opsDay(_dates.end)}',
                  ),
                ),
                if (director && report.type != 'Trend')
                  TextButton.icon(
                    onPressed: busy ? null : () => _export(query),
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Sao chép CSV'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: report.type == 'Trend'
                ? OpsAsync(
                    value: ref.watch(_trend(query)),
                    onRetry: () => ref.invalidate(_trend(query)),
                    data: (rows) => ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        if (rows.isEmpty)
                          const Text('Không có dữ liệu trong khoảng đã chọn.'),
                        for (final row in rows)
                          OpsTile(
                            title:
                                '${opsDay(DateTime.parse(row.from))} – ${opsDay(DateTime.parse(row.to))}',
                            subtitle:
                                'Điểm danh ${_rate(row.attendance)} • ${row.rehearsals} buổi\n'
                                'Hoàn thành ${_rate(row.completion)} • ${row.due} bài đến hạn',
                          ),
                      ],
                    ),
                  )
                : OpsAsync(
                    value: ref.watch(_report(query)),
                    onRetry: () => ref.invalidate(_report(query)),
                    data: (result) {
                      final (columns, page) = result;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          if (page.items.isEmpty)
                            const Text(
                              'Không có dữ liệu trong khoảng đã chọn.',
                            ),
                          for (final row in page.items)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    for (final column in columns)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: Text(column.label)),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                _value(column, row[column.key]),
                                                textAlign: TextAlign.end,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
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
                          OpsPaging(
                            page: _page,
                            previous: _page > 1
                                ? () => setState(() => _page--)
                                : null,
                            next: page.hasNextPage
                                ? () => setState(() => _page++)
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
