import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/member_choir_visuals.dart';
import '../../../core/di/core_providers.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../staff_workspace/presentation/staff_ops_widgets.dart';
import '../data/choir_membership_api.dart';

final _changes = StreamProvider.autoDispose((ref) {
  return ref
      .watch(signalRServiceProvider)
      .notificationStream
      .where(
        (data) =>
            data['referenceType'] == 'ChoirJoinRequest' ||
            data['type'] == 'ChoirChanged' ||
            data['type'] == 13,
      );
});

final _requests = FutureProvider.autoDispose.family((ref, (int, String?) key) {
  ref.watch(_changes);
  return ref
      .watch(choirMembershipApiProvider)
      .requests(key.$1, choirId: key.$2);
});

final _catalog = FutureProvider.autoDispose(
  (ref) => ref.watch(choirMembershipApiProvider).catalog(),
);

class ChoirMembershipScreen extends ConsumerStatefulWidget {
  const ChoirMembershipScreen({super.key, this.staff = false, this.choirId});

  final bool staff;
  final String? choirId;

  @override
  ConsumerState<ChoirMembershipScreen> createState() =>
      _ChoirMembershipScreenState();
}

class _ChoirMembershipScreenState extends ConsumerState<ChoirMembershipScreen>
    with OpsActions<ChoirMembershipScreen> {
  int _page = 1;

  Future<void> _create(String? currentChoirId) async {
    final api = ref.read(choirMembershipApiProvider);
    final draft = await showDialog<({String choirId, String? message})>(
      context: context,
      builder: (_) => _ChooseChoirDialog(currentChoirId: currentChoirId),
    );
    if (!mounted || draft == null) return;
    if (await runAction(
      () => api.submit(draft.choirId, message: draft.message),
    )) {
      _refresh('Đã gửi yêu cầu.');
    }
  }

  Future<void> _review(
    ChoirJoinRequest request,
    ChoirRequestAction action,
  ) async {
    final api = ref.read(choirMembershipApiProvider);
    final name = request.choirName;
    final title = switch (action) {
      ChoirRequestAction.approve =>
        request.isInvitation ? 'Đồng ý vào ca đoàn?' : 'Chấp thuận yêu cầu?',
      ChoirRequestAction.reject =>
        request.isInvitation ? 'Từ chối lời mời' : 'Từ chối yêu cầu',
      ChoirRequestAction.cancel =>
        request.isInvitation ? 'Hủy lời mời?' : 'Hủy yêu cầu?',
    };
    String? reason;
    if (action == ChoirRequestAction.reject) {
      reason = await opsText(
        context,
        title,
        'Lý do từ chối',
        requiredText: !request.isInvitation,
        outlinedCancel: !widget.staff,
      );
      if (reason == null) return;
    } else {
      final label = action == ChoirRequestAction.approve
          ? 'Đồng ý'
          : 'Xác nhận hủy';
      final agreed = !widget.staff && action == ChoirRequestAction.cancel
          ? await _confirmMemberChange(title, name, label)
          : await opsConfirm(
              context,
              title,
              name,
              label,
              outlinedCancel: !widget.staff,
            );
      if (!agreed) return;
    }
    if (!mounted) return;
    if (await runAction(() => api.review(request, action, reason: reason))) {
      _refresh(
        switch (action) {
          ChoirRequestAction.approve => 'Đã chấp thuận.',
          ChoirRequestAction.reject => 'Đã từ chối.',
          ChoirRequestAction.cancel => 'Đã hủy.',
        },
        membershipChanged:
            !widget.staff && action == ChoirRequestAction.approve,
      );
    }
  }

  Future<void> _leave(String choirId, String choirName) async {
    final api = ref.read(choirMembershipApiProvider);
    final agreed = await _confirmMemberChange(
      'Rời ca đoàn?',
      'Sau khi rời $choirName, các phân công phục vụ sắp tới của bạn có thể được gỡ.',
      'Rời ca đoàn',
    );
    if (!mounted || !agreed) return;
    if (await runAction(() => api.leave(choirId))) {
      _refresh('Đã rời ca đoàn.', membershipChanged: true);
    }
  }

  Future<bool> _confirmMemberChange(
    String title,
    String body,
    String label,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                        0,
                        MemberChoirStyle.dialogActionHeight,
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(label),
                  ),
                  OutlinedButton(
                    style: MemberChoirStyle.cancelButtonStyle,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Hủy'),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
  }

  void _refresh(String message, {bool membershipChanged = false}) {
    if (!mounted) return;
    setState(() => _page = 1);
    ref.invalidate(_requests);
    if (membershipChanged) {
      _refreshMembershipViews();
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _refreshMembershipViews() {
    ref.invalidate(currentMemberProfileProvider);
    ref.invalidate(calendarNotifierProvider);
    ref.invalidate(eventDetailProvider);
    ref.invalidate(rehearsalDetailProvider);
  }

  void _reload() {
    ref.invalidate(_requests((_page, widget.choirId)));
    if (!widget.staff) {
      ref.invalidate(currentMemberProfileProvider);
      ref.invalidate(_catalog);
    }
  }

  Widget _requestCard(ChoirJoinRequest request) {
    final pending = request.status == ChoirRequestStatus.pending;
    final canReview = pending && widget.staff != request.isInvitation;
    final title = request.isInvitation ? 'Lời mời' : 'Yêu cầu';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(
              widget.staff
                  ? '$title · ${request.member}'
                  : '$title · ${request.choirName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${request.status.label} · ${opsTime(request.createdAt)}'),
            if (widget.staff) Text(request.choirName),
            if (request.currentChoirName case final String from?
                when pending && !request.isInvitation)
              Text('Ca đoàn hiện tại: $from'),
            if (request.message?.trim() case final String message?
                when message.isNotEmpty)
              Text(message),
            if (request.rejectReason?.trim() case final String reason?
                when reason.isNotEmpty)
              Text('Lý do từ chối: $reason'),
            if (pending)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (canReview) ...[
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => _review(request, ChoirRequestAction.approve),
                      child: Text(
                        request.isInvitation ? 'Đồng ý' : 'Chấp thuận',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => _review(request, ChoirRequestAction.reject),
                      child: const Text('Từ chối'),
                    ),
                  ] else
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => _review(request, ChoirRequestAction.cancel),
                      child: Text(
                        request.isInvitation ? 'Hủy lời mời' : 'Hủy yêu cầu',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.staff) {
      ref.listen(_changes, (previous, next) {
        if (next is AsyncData && previous != next) _refreshMembershipViews();
      });
    }
    final provider = _requests((_page, widget.choirId));
    final requests = ref.watch(provider);
    final current = requests.asData?.value.items.firstOrNull;
    final profileNames = widget.staff || current != null || !requests.hasValue
        ? null
        : ref.watch(currentMemberProfileProvider).asData?.value.choirNames;
    final profileName = profileNames?.length == 1 ? profileNames!.single : null;
    final catalog = profileName == null ? null : ref.watch(_catalog);
    // BE enforces unique choir names. Require one exact catalog match.
    final matches = catalog?.asData?.value.where(
      (choir) => choir.name == profileName,
    );
    final currentChoirId =
        current?.currentChoirId ??
        (matches?.length == 1 ? matches!.single.id : null);
    final currentChoirName = current?.currentChoirName ?? profileName;
    final page = OpsPage(
      title: widget.staff ? 'Yêu cầu và lời mời' : 'Ca đoàn của tôi',
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: busy ? null : _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: OpsAsync(
        value: requests,
        onRetry: _reload,
        data: (page) {
          final paging = OpsPaging(
            page: _page,
            previous: page.hasPreviousPage && !busy
                ? () => setState(() => _page--)
                : null,
            next: page.hasNextPage && !busy
                ? () => setState(() => _page++)
                : null,
          );
          final content = <Widget>[
            actionState,
            if (!widget.staff) ...[
              OpsTile(
                icon: Icons.groups_outlined,
                title: 'Ca đoàn hiện tại',
                subtitle:
                    currentChoirName ??
                    (profileNames?.isEmpty == true ||
                            (current != null && currentChoirId == null)
                        ? 'Chưa tham gia ca đoàn'
                        : 'Chưa xác minh được ca đoàn'),
              ),
              if (catalog?.isLoading == true)
                const LinearProgressIndicator()
              else if (catalog?.hasError == true)
                TextButton(
                  onPressed: () => ref.invalidate(_catalog),
                  child: const Text('Tải lại thông tin ca đoàn'),
                ),
              FilledButton(
                onPressed:
                    busy ||
                        page.items.any(
                          (row) =>
                              !row.isInvitation &&
                              row.status == ChoirRequestStatus.pending,
                        )
                    ? null
                    : () => _create(currentChoirId),
                child: Text(
                  currentChoirId == null && currentChoirName == null
                      ? 'Gửi yêu cầu vào ca đoàn'
                      : 'Yêu cầu chuyển ca đoàn',
                ),
              ),
              if (currentChoirId != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => _leave(
                          currentChoirId,
                          currentChoirName ?? 'ca đoàn hiện tại',
                        ),
                  child: const Text('Rời ca đoàn'),
                ),
              ],
              const SizedBox(height: 12),
            ],
            if (widget.staff && page.items.isEmpty)
              const Text('Chưa có yêu cầu hoặc lời mời.'),
            for (final request in page.items) _requestCard(request),
            if (widget.staff || page.items.isNotEmpty) paging,
          ];
          if (widget.staff) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: content,
            );
          }
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(children: content),
              ),
              if (page.items.isEmpty)
                MemberEmptyStateSliver(
                  footer: paging,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Chưa có yêu cầu hoặc lời mời.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
    return widget.staff
        ? page
        : Theme(data: MemberChoirStyle.theme(context), child: page);
  }
}

class _ChooseChoirDialog extends ConsumerStatefulWidget {
  const _ChooseChoirDialog({this.currentChoirId});
  final String? currentChoirId;

  @override
  ConsumerState<_ChooseChoirDialog> createState() => _ChooseChoirDialogState();
}

class _ChooseChoirDialogState extends ConsumerState<_ChooseChoirDialog> {
  String? _choirId;
  String _message = '';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(_catalog);
    final options = [
      for (final row in catalog.asData?.value ?? const <JoinableChoir>[])
        if (row.id != widget.currentChoirId) row,
    ];
    final valid =
        options.any((row) => row.id == _choirId) && _message.length <= 500;
    return AlertDialog(
      title: const Text('Gửi yêu cầu ca đoàn'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          if (catalog.isLoading)
            const LinearProgressIndicator()
          else if (catalog.hasError)
            TextButton(
              onPressed: () => ref.invalidate(_catalog),
              child: const Text('Tải lại danh sách ca đoàn'),
            )
          else if (options.isEmpty)
            const Text('Hiện chưa có ca đoàn phù hợp.')
          else ...[
            MemberChoiceField<String>(
              label: 'Ca đoàn đăng ký',
              value: _choirId,
              hint: 'Chọn ca đoàn',
              items: [
                for (final choir in options)
                  DropdownMenuItem(
                    value: choir.id,
                    child: Text(choir.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _choirId = value),
            ),
            const Text(
              'Nếu bạn đang thuộc một ca đoàn, yêu cầu được duyệt sẽ chuyển bạn sang ca đoàn mới.',
            ),
            TextField(
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Lời nhắn (tùy chọn)',
                errorText: _message.length > 500
                    ? 'Lời nhắn tối đa 500 ký tự.'
                    : null,
              ),
              onChanged: (value) => setState(() => _message = value),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: !valid
              ? null
              : () {
                  final message = _message.trim();
                  Navigator.pop(context, (
                    choirId: _choirId!,
                    message: message.isEmpty ? null : message,
                  ));
                },
          child: const Text('Gửi yêu cầu'),
        ),
      ],
    );
  }
}
