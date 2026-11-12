import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../music/data/music_file_loader.dart';
import '../data/staff_operations_api.dart';
import '../data/staff_dashboard_providers.dart';
import '../data/staff_practice_providers.dart';
import 'staff_ops_widgets.dart';

final _submissions = FutureProvider.autoDispose.family(
  (ref, (int, String?, String?) filter) => ref
      .watch(staffOperationsApiProvider)
      .submissions(filter.$1, filter.$2, filter.$3),
);
final _submission = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(staffOperationsApiProvider).submission(id),
);

String _status(String value) => switch (value) {
  'Submitted' => 'Chờ chấm',
  'Passed' => 'Đạt yêu cầu',
  'NeedsRevision' => 'Cần luyện thêm',
  'Overdue' => 'Quá hạn',
  _ => value,
};

Future<void> showAudioScore(BuildContext context, AudioScore score) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Điểm tham khảo ${score.score}/100'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (score.track.isNotEmpty) Text(score.track),
            Text('Cao độ ${score.pitch}/100'),
            Text('Nhịp ${score.rhythm}/100'),
            Text('Độ phủ ${score.coverage}%'),
            const SizedBox(height: 8),
            const Text('Kết quả phân tích tự động.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );

class StaffSubmissionsScreen extends StatelessWidget {
  const StaffSubmissionsScreen({
    super.key,
    this.assignmentId,
    this.assignmentTitle,
  });

  final String? assignmentId;
  final String? assignmentTitle;

  @override
  Widget build(BuildContext context) => OpsPage(
    title: assignmentTitle ?? 'Chấm bản thu',
    child: StaffSubmissionList(assignmentId: assignmentId),
  );
}

class StaffSubmissionList extends ConsumerStatefulWidget {
  const StaffSubmissionList({super.key, this.assignmentId, this.initialStatus});
  final String? assignmentId;
  final String? initialStatus;

  @override
  ConsumerState<StaffSubmissionList> createState() =>
      _StaffSubmissionListState();
}

class _StaffSubmissionListState extends ConsumerState<StaffSubmissionList> {
  int _page = 1;
  late String? _statusFilter = widget.initialStatus;

  @override
  Widget build(BuildContext context) {
    final provider = _submissions((_page, _statusFilter, widget.assignmentId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: OpsChoiceField(
                  label: 'Trạng thái',
                  value: _statusFilter,
                  optional: true,
                  emptyLabel: 'Tất cả',
                  options: [
                    for (final status in [
                      'Submitted',
                      'Passed',
                      'NeedsRevision',
                      'Overdue',
                    ])
                      (id: status, name: _status(status)),
                  ],
                  onChanged: (status) => setState(() {
                    _page = 1;
                    _statusFilter = status;
                  }),
                ),
              ),
              IconButton(
                tooltip: 'Tải lại bản thu',
                onPressed: () => ref.invalidate(provider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: OpsAsync(
            value: ref.watch(provider),
            onRetry: () => ref.invalidate(provider),
            data: (page) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (page.items.isEmpty)
                  const Center(child: Text('Chưa có bản thu phù hợp.')),
                for (final row in page.items)
                  OpsTile(
                    icon: Icons.mic_none,
                    title: row.title,
                    subtitle:
                        '${row.member} • Lần ${row.attempt}\n${_status(row.status)} • ${opsTime(row.date)}',
                    onTap: () async {
                      await context.push(opsPath('staff-submission', row.id));
                      if (mounted) ref.invalidate(provider);
                    },
                  ),
                OpsPaging(
                  page: _page,
                  previous: _page > 1 ? () => setState(() => _page--) : null,
                  next: page.hasNextPage ? () => setState(() => _page++) : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class StaffSubmissionScreen extends ConsumerStatefulWidget {
  const StaffSubmissionScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<StaffSubmissionScreen> createState() =>
      _StaffSubmissionScreenState();
}

class _StaffSubmissionScreenState extends ConsumerState<StaffSubmissionScreen>
    with OpsActions<StaffSubmissionScreen> {
  final _player = AudioPlayer();
  bool _prepared = false;
  Duration _duration = Duration.zero;
  StaffOperationsApi get _api => ref.read(staffOperationsApiProvider);

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _listen() async {
    final played = await runAction(() async {
      if (_player.state == PlayerState.playing) {
        await _player.pause();
        return;
      }
      if (!_prepared) {
        final fresh = await _api.submission(widget.id);
        if (!mounted) return;
        if (fresh.audioUrl?.isNotEmpty != true) {
          throw StateError('No recording URL.');
        }
        await _player.setReleaseMode(ReleaseMode.stop);
        if (!mounted) return;
        await _player.setSource(
          UrlSource(MusicFileLoader.validatedUrl(fresh.audioUrl!).toString()),
        );
        if (!mounted) return;
        _duration = await _player.getDuration() ?? Duration.zero;
        _prepared = mounted;
      } else if (_player.state == PlayerState.completed) {
        await _player.seek(Duration.zero);
      }
      if (mounted) await _player.resume();
    });
    if (mounted && !played) _prepared = false;
  }

  Future<void> _grade() async {
    AudioScore? score;
    if (await runAction(() async {
          score = await _api.scoreSubmission(widget.id);
        }) &&
        mounted) {
      await showAudioScore(context, score!);
    }
  }

  Future<void> _review(StaffSubmission submission) async {
    final reviewed =
        submission.status == 'Passed' || submission.status == 'NeedsRevision';
    var result = reviewed ? '' : 'Passed';
    var comment = '';
    final input = await showDialog<(String?, String)>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(reviewed ? 'Thêm nhận xét' : 'Chấm bản thu'),
          scrollable: true,
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: result,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kết quả'),
                  items: [
                    if (reviewed)
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Giữ kết quả hiện tại'),
                      ),
                    for (final status in ['Passed', 'NeedsRevision'])
                      DropdownMenuItem(
                        value: status,
                        child: Text(_status(status)),
                      ),
                  ],
                  onChanged: (value) => update(() => result = value!),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Nhận xét'),
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) => update(() => comment = value.trim()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed:
                  (reviewed || result == 'NeedsRevision') && comment.isEmpty
                  ? null
                  : () => Navigator.pop(context, (
                      result.isEmpty ? null : result,
                      comment,
                    )),
              child: const Text('Lưu đánh giá'),
            ),
          ],
        ),
      ),
    );
    if (input == null || !mounted) return;
    if (await runAction(
          () => _api.review(
            widget.id,
            reviewed: reviewed,
            result: input.$1,
            comment: input.$2,
          ),
        ) &&
        mounted) {
      ref.invalidate(_submission(widget.id));
      ref.invalidate(staffPreparationProgressProvider);
      ref.invalidate(staffPendingSubmissionsCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _submission(widget.id);
    return OpsPage(
      title: 'Chi tiết bản thu',
      child: OpsAsync(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (submission) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            actionState,
            OpsTile(
              title: submission.title,
              subtitle:
                  '${submission.member} • Lần ${submission.attempt}\n${opsTime(submission.date)} • ${_status(submission.status)}',
            ),
            if (submission.audioUrl != null)
              StreamBuilder<PlayerState>(
                stream: _player.onPlayerStateChanged,
                builder: (context, snapshot) {
                  final playing =
                      (snapshot.data ?? _player.state) == PlayerState.playing;
                  return OutlinedButton.icon(
                    onPressed: busy ? null : _listen,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    label: Text(playing ? 'Tạm dừng' : 'Nghe bản thu'),
                  );
                },
              ),
            StreamBuilder<Duration>(
              stream: _player.onPositionChanged,
              builder: (context, snapshot) {
                final duration = _duration.inMilliseconds;
                if (duration == 0) return const SizedBox.shrink();
                return Slider(
                  max: duration.toDouble(),
                  value: (snapshot.data?.inMilliseconds ?? 0)
                      .clamp(0, duration)
                      .toDouble(),
                  onChanged: busy
                      ? null
                      : (value) =>
                            _player.seek(Duration(milliseconds: value.round())),
                );
              },
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : _grade,
              icon: const Icon(Icons.graphic_eq),
              label: const Text('Phân tích tự động'),
            ),
            if (submission.status != 'Overdue')
              FilledButton.icon(
                onPressed: busy ? null : () => _review(submission),
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(
                  submission.status == 'Passed' ||
                          submission.status == 'NeedsRevision'
                      ? 'Thêm nhận xét'
                      : 'Lưu đánh giá',
                ),
              ),
            const SizedBox(height: 16),
            for (final row in submission.feedback)
              OpsTile(
                title: row.reviewer ?? 'Ca trưởng',
                subtitle: [_status(row.result), ?row.comment].join('\n'),
              ),
          ],
        ),
      ),
    );
  }
}
