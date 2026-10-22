import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/realtime/signalr_service.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';
import 'package:harmonia_mobile/features/profile/data/profile_models.dart';
import 'package:harmonia_mobile/features/profile/data/profile_repository.dart';

import 'package:harmonia_mobile/features/profile/presentation/profile_screen.dart';

import 'support/fake_profile_repository.dart';

class _SignalR extends SignalRService {
  _SignalR(super.storage);
  @override
  Future<void> connect() async {}
  final events = StreamController<Map<String, dynamic>>.broadcast();
  final connections = StreamController<void>.broadcast();
  @override
  Stream<void> get connectedStream => connections.stream;
  @override
  Stream<Map<String, dynamic>> get notificationStream => events.stream;
  @override
  void dispose() {
    events.close();
    connections.close();
    super.dispose();
  }
}

class _Profiles extends MockProfileRepositoryImpl {
  @override
  Future<MemberSkill?> getSkillById(String id) async =>
      skills.where((s) => s.id == id).firstOrNull;

  List<MemberSkill> skills = [_skill(SkillApprovalStatus.pending)];
  final statuses = <String?>[];
  Completer<PagedList<MemberSkill>>? nextResponse;

  @override
  Future<PagedList<MemberSkill>> getSkillsPaged({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    statuses.add(status);
    final response = nextResponse;
    nextResponse = null;
    if (response != null) return response.future;
    final filtered = skills
        .where(
          (s) =>
              status == null ||
              s.status.name.toLowerCase() == status.toLowerCase(),
        )
        .toList();
    return PagedList<MemberSkill>(
      items: filtered.skip((pageNumber - 1) * pageSize).take(pageSize).toList(),
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: filtered.length,
      totalPages: (filtered.length / pageSize).ceil(),
      hasPreviousPage: pageNumber > 1,
      hasNextPage: pageNumber * pageSize < filtered.length,
    );
  }
}

MemberSkill _skill(SkillApprovalStatus status) => MemberSkill(
  id: 'declaration',
  name: 'Thanh nhạc',
  categoryName: 'Giọng hát',
  status: status,
  rejectReason: status == SkillApprovalStatus.rejected
      ? 'Cần luyện thêm'
      : null,
);

PagedList<MemberSkill> _page(List<MemberSkill> items) => PagedList(
  items: items,
  pageNumber: 1,
  pageSize: 10,
  totalCount: items.length,
  totalPages: 1,
  hasPreviousPage: false,
  hasNextPage: false,
);

Map<String, dynamic> _review({
  String id = 'review',
  Object type = 'SkillReview',
}) => {
  'id': id,
  'type': type,
  'title': 'Kết quả duyệt kỹ năng',
  'content': '',
  'referenceType': (type == 6 || type == 'SkillReview')
      ? 'MemberSkill'
      : 'PracticeAssignment',
  'referenceId': 'declaration',
  'isRead': false,
  'createdAt': '2026-10-17T00:00:00Z',
};

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late SessionManager session;
  late _SignalR signalR;
  late _Profiles profiles;

  setUp(() async {
    final fontAssets = {
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
      ])
        'fonts/PlusJakartaSans-$weight.ttf': [
          {'asset': 'fonts/PlusJakartaSans-$weight.ttf'},
        ],
    };
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      final key = const StringCodec().decodeMessage(message)!;
      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(fontAssets);
      }
      if (key.startsWith('fonts/PlusJakartaSans-')) return ByteData(0);
      return null;
    });
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService();
    session = SessionManager(storage);
    await session.markAuthenticated(role: 'ChoirMember');
    signalR = _SignalR(storage);
    profiles = _Profiles();
    container = ProviderContainer(
      overrides: [
        sessionManagerProvider.overrideWithValue(session),
        signalRServiceProvider.overrideWithValue(signalR),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    signalR.dispose();
    session.dispose();
  });

  test(
    'decodes backend SkillReview instead of falling back to director note',
    () {
      expect(NotificationDto.fromJson(_review()).type.name, 'skillReview');
      expect(
        NotificationDto.fromJson(_review(type: 6)).type.name,
        'skillReview',
      );
      expect(
        NotificationDto.fromJson(_review(type: 'EventPublished')).type,
        NotificationType.weekPublished,
      );
    },
  );

  test('approval updates the mounted skills list and duplicate events do not refetch', () async {
    await container.read(memberSkillsNotifierProvider.notifier).loadInitial();
    expect(
      container.read(memberSkillsNotifierProvider).items.single.status,
      SkillApprovalStatus.pending,
    );
    profiles.skills = [_skill(SkillApprovalStatus.approved)];
    signalR.events.add(_review());
    await pumpEventQueue();
    expect(
      container.read(memberSkillsNotifierProvider).items.single.status,
      SkillApprovalStatus.approved,
    );
    final count = profiles.statuses.length;
    signalR.events.add(_review());
    signalR.events.add(_review(id: 'unrelated', type: 4));
    await pumpEventQueue();
    expect(profiles.statuses.length, count);
  });

  test('rejection refresh respects the selected Pending filter', () async {
    await container
        .read(memberSkillsNotifierProvider.notifier)
        .loadInitial(status: 'Pending');
    profiles.skills = [_skill(SkillApprovalStatus.rejected)];
    signalR.events.add(_review());
    await pumpEventQueue();
    final state = container.read(memberSkillsNotifierProvider);
    expect(state.items, isEmpty);
    expect(state.totalCount, 0);
    expect(profiles.statuses.last, 'Pending');
  });

  test('approval during initial load wins over stale Pending response without stuck loading', () async {
    final pending = Completer<PagedList<MemberSkill>>();
    profiles.nextResponse = pending;
    final loading = container
        .read(memberSkillsNotifierProvider.notifier)
        .loadInitial();
    profiles.skills = [_skill(SkillApprovalStatus.approved)];
    signalR.events.add(_review());
    await pumpEventQueue();
    pending.complete(_page([_skill(SkillApprovalStatus.pending)]));
    await loading;
    final state = container.read(memberSkillsNotifierProvider);
    expect(state.items.single.status, SkillApprovalStatus.approved);
    expect(state.isLoading, isFalse);
    expect(state.isRefreshing, isFalse);
  });

  test('reconnect catches up a decision missed while offline', () async {
    await container.read(memberSkillsNotifierProvider.notifier).loadInitial();
    profiles.skills = [_skill(SkillApprovalStatus.approved)];
    signalR.connections.add(null);
    await pumpEventQueue();
    expect(
      container.read(memberSkillsNotifierProvider).items.single.status,
      SkillApprovalStatus.approved,
    );
  });
  test(
    'load more waits for realtime refresh before choosing the next page',
    () async {
      profiles.skills = List.generate(
        40,
        (i) => MemberSkill(
          id: 'skill-$i',
          name: 'Thanh nhạc $i',
          categoryName: 'Giọng hát',
          status: SkillApprovalStatus.approved,
        ),
      );
      final notifier = container.read(memberSkillsNotifierProvider.notifier);
      await notifier.loadInitial();
      await notifier.loadMore();
      await notifier.loadMore();
      expect(container.read(memberSkillsNotifierProvider).pageNumber, 3);
      final response = Completer<PagedList<MemberSkill>>();
      profiles.nextResponse = response;
      final refreshing = notifier.refresh();
      final calls = profiles.statuses.length;
      await notifier.loadMore();
      expect(profiles.statuses.length, calls);
      response.complete(
        PagedList(
          items: profiles.skills.take(10).toList(),
          pageNumber: 1,
          pageSize: 10,
          totalCount: 40,
          totalPages: 4,
          hasPreviousPage: false,
          hasNextPage: true,
        ),
      );
      await refreshing;
      await notifier.loadMore();
      final state = container.read(memberSkillsNotifierProvider);
      expect(state.pageNumber, 2);
      expect(
        state.items.map((s) => s.id),
        List.generate(20, (i) => 'skill-$i'),
      );
    },
  );

  testWidgets(
    'open skill detail shows the new rejection reason without reopening',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final skill = find.text('Thanh nhạc').first;
      await tester.ensureVisible(skill);
      await tester.tap(skill);
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết kỹ năng'), findsOneWidget);
      expect(find.text('Cần luyện thêm'), findsNothing);
      profiles.skills = [_skill(SkillApprovalStatus.rejected)];
      signalR.events.add(_review());
      await tester.pumpAndSettle();
      expect(find.text('Cần luyện thêm'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('returning from background catches up a missed approval', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    profiles.skills = [_skill(SkillApprovalStatus.approved)];
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      container.read(memberSkillsNotifierProvider).items.single.status,
      SkillApprovalStatus.approved,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('late refresh cannot restore skills after logout', () async {
    await container.read(memberSkillsNotifierProvider.notifier).loadInitial();
    final pending = Completer<PagedList<MemberSkill>>();
    profiles.nextResponse = pending;
    signalR.events.add(_review());
    await pumpEventQueue();
    await session.endSession();
    pending.complete(_page([_skill(SkillApprovalStatus.approved)]));
    await pumpEventQueue();
    expect(container.read(memberSkillsNotifierProvider).items, isEmpty);
    final count = profiles.statuses.length;
    signalR.events.add(_review(id: 'late-event'));
    await pumpEventQueue();
    expect(profiles.statuses.length, count);
  });
}
