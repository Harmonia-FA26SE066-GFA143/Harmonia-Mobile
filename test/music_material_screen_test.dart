import 'support/fake_music_repository.dart';
import 'support/fake_practice_repository.dart';
import 'support/fake_profile_repository.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart'
    show publicAppSettingsProvider;
import 'package:harmonia_mobile/app/widgets/member_choir_visuals.dart'
    show MemberChoirArt, MemberChoirArtwork;
import 'package:harmonia_mobile/features/music/presentation/music_library_screen.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart' as music;
import 'package:harmonia_mobile/features/music/data/music_repository.dart';
import 'package:harmonia_mobile/features/music/data/song_models.dart'
    show SongListItem;
import 'package:harmonia_mobile/features/music/presentation/song_detail_screen.dart';
import 'package:harmonia_mobile/features/practice/data/practice_models.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart'
    show practiceRepositoryProvider;
import 'package:harmonia_mobile/features/music/presentation/music_material_screen.dart';
import 'package:harmonia_mobile/features/music/presentation/music_library_notifier.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';
import 'package:harmonia_mobile/features/profile/data/profile_models.dart';
import 'package:harmonia_mobile/features/profile/data/profile_repository.dart'
    show profileRepositoryProvider;

class ProgressRepository extends MockMusicRepositoryImpl {
  final pending = Completer<void>();
  final updates = <(String, music.LearningStatus)>[];
  music.LearningStatus saved = music.LearningStatus.notStarted;
  @override
  Future<PagedList<music.SongDto>> getSongsPage(
    music.SearchSongsRequest request,
  ) async => const PagedList(
    items: [],
    pageNumber: 1,
    pageSize: 20,
    totalCount: 0,
    totalPages: 0,
    hasPreviousPage: false,
    hasNextPage: false,
  );
  @override
  Future<PagedList<music.MusicMaterialDetailDto>> getMyMaterialsPage(
    music.SearchMusicMaterialsRequest request,
  ) async => PagedList(
    items: [(await getMyMaterial('material-b', 'song-a'))!],
    pageNumber: 1,
    pageSize: 20,
    totalCount: 1,
    totalPages: 1,
    hasPreviousPage: false,
    hasNextPage: false,
  );
  @override
  Future<music.MusicMaterialDetailDto?> getMyMaterial(
    String id,
    String songId,
  ) async => music.MusicMaterialDetailDto(
    id: id,
    songId: songId,
    materialType: music.MaterialType.sheetMusic,
    title: 'Bản nhạc B',
    fileName: 'sheet.pdf',
    fileUrl: 'https://example.invalid/sheet.pdf',
    createdAt: '2026-10-15T00:00:00Z',
    learningStatus: saved,
  );
  @override
  Future<void> updateMaterialProgress(
    String materialId,
    music.LearningStatus status,
  ) {
    updates.add((materialId, status));
    return pending.future.then((_) {
      saved = status;
    });
  }
}

class SongScoreRepository extends MockMusicRepositoryImpl {
  @override
  Future<SongListItem?> getSongDetail(String songId) async =>
      MockMusicData.songs.first.copyWith(
        materials: const [
          music.MusicMaterialDto(
            id: 'score-a',
            songId: 'song-01',
            materialType: music.MaterialType.interactiveScore,
            title: 'Bản tương tác của Ca viên',
            fileName: 'score.mxl',
            fileUrl: '',
            createdAt: '',
          ),
        ],
      );
}

class InteractiveScoreRepository extends MockMusicRepositoryImpl {
  String? playbackMaterialId;

  @override
  Future<music.MusicMaterialDetailDto?> getMyMaterial(
    String id,
    String songId,
  ) async => music.MusicMaterialDetailDto.fromJson({
    'id': id,
    'songId': songId,
    'materialType': 'InteractiveScore',
    'title': 'Bản nhạc thử',
    'fileName': 'score.mxl',
  });

  @override
  Future<music.MusicMaterialPlaybackDto> getMaterialPlayback(String id) async {
    playbackMaterialId = id;
    throw const AppException(
      code: 'MATERIAL_PLAYBACK_UNAVAILABLE',
      message: 'Playback unavailable.',
      statusCode: 409,
    );
  }
}

void main() {
  testWidgets('MusicXML requests rendered playback for the selected material', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = SessionManager(SecureStorageService());
    await session.markAuthenticated(role: 'ChoirMember');
    final repository = InteractiveScoreRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          musicRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: MusicMaterialScreen(materialId: 'score-a', songId: 'song-a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phát bản nhạc'));
    await tester.pumpAndSettle();

    expect(repository.playbackMaterialId, 'score-a');
    expect(
      find.textContaining('Tài liệu chưa có dữ liệu phát'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets(
    'failed progress update restores the displayed server status and uses the selected material ID',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      final repository = ProgressRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            musicRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: MusicMaterialScreen(
              materialId: 'material-b',
              songId: 'song-a',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<music.LearningStatus>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đã thuộc').last);
      await tester.pump();
      expect(repository.updates, [
        ('material-b', music.LearningStatus.learned),
      ]);
      repository.pending.completeError(const NetworkException());
      await tester.pumpAndSettle();
      expect(find.text('Chưa học'), findsOneWidget);
      expect(find.text('Đã cập nhật tiến độ học'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets('successful progress update keeps library tab and filters', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = SessionManager(SecureStorageService());
    await session.markAuthenticated(role: 'ChoirMember');
    final repository = ProgressRepository();
    final container = ProviderContainer(
      overrides: [
        sessionManagerProvider.overrideWithValue(session),
        musicRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final subscription = container.listen(musicLibraryProvider, (_, _) {});
    await container
        .read(musicLibraryProvider.notifier)
        .refresh(
          materialsTab: true,
          keyword: 'Bản',
          materialType: music.MaterialType.sheetMusic,
          learningStatus: music.LearningStatus.notStarted,
          replaceFilters: true,
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MusicMaterialScreen(materialId: 'material-b', songId: 'song-a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<music.LearningStatus>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã thuộc').last);
    await tester.pump();
    repository.pending.complete();
    await tester.pumpAndSettle();
    final state = container.read(musicLibraryProvider);
    expect(state.materialsTab, isTrue);
    expect(state.keyword, 'Bản');
    expect(state.materialType, music.MaterialType.sheetMusic);
    expect(state.learningStatus, music.LearningStatus.notStarted);
    expect(find.text('Đã thuộc'), findsOneWidget);
    expect(find.text('Đã cập nhật tiến độ học'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    subscription.close();
    container.dispose();
    session.dispose();
  });
  testWidgets(
    'member song details opens the interactive material on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SongDetailScreen(songId: 'song-01'),
          ),
          GoRoute(
            path: '/interactive-score/:id',
            builder: (_, state) => Scaffold(
              body: Text('Trình phát ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            musicRepositoryProvider.overrideWithValue(SongScoreRepository()),
            practiceRepositoryProvider.overrideWithValue(
              MockPracticeRepositoryImpl(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final score = find.text('Bản tương tác của Ca viên');
      await tester.scrollUntilVisible(score, 160);
      await tester.pumpAndSettle();
      await tester.tap(score);
      await tester.pumpAndSettle();
      expect(find.text('Trình phát score-a'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('returning from a material keeps the library tab and query', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = SessionManager(SecureStorageService());
    await session.markAuthenticated(role: 'ChoirMember');
    final repository = ProgressRepository();
    final container = ProviderContainer(
      overrides: [
        sessionManagerProvider.overrideWithValue(session),
        musicRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const MusicLibraryScreen()),
        GoRoute(
          path: '/music-material/:id',
          builder: (_, state) => MusicMaterialScreen(
            materialId: state.pathParameters['id']!,
            songId: state.uri.queryParameters['songId']!,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await container
        .read(musicLibraryProvider.notifier)
        .refresh(
          materialsTab: true,
          keyword: 'Bản',
          materialType: music.MaterialType.sheetMusic,
          replaceFilters: true,
        );
    await tester.pumpAndSettle();
    final material = find.text('Bản nhạc B');
    await tester.scrollUntilVisible(
      material,
      180,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(material);
    await tester.pumpAndSettle();
    expect(find.text('Tài liệu học'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final state = container.read(musicLibraryProvider);
    expect(state.materialsTab, isTrue);
    expect(state.keyword, 'Bản');
    expect(state.materialType, music.MaterialType.sheetMusic);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    container.dispose();
    session.dispose();
  });

  testWidgets(
    'SongDetailScreen renders Stitch 14 sections, inline part-only audio card, notes, and SafeArea CTA at 360dp',
    (tester) async {
      _stubAudioChannels(tester);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);

      final songRepo = _StitchSongDetailRepository();
      final practiceRepo = _StitchPracticeRepo();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SongDetailScreen(songId: 'song-stitch-14'),
          ),
          GoRoute(
            path: '/interactive-score/:id',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Score ${state.pathParameters['id']}'),
            ),
          ),
          GoRoute(
            path: '/music-material/:id',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Material ${state.pathParameters['id']}'),
            ),
          ),
          GoRoute(
            path: '/practice-detail/:id',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Practice ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            musicRepositoryProvider.overrideWithValue(songRepo),
            practiceRepositoryProvider.overrideWithValue(practiceRepo),
            publicAppSettingsProvider.overrideWith(
              (_) async =>
                  const PublicAppSettings(choirName: 'Ca đoàn Cecilia'),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CA ĐOÀN CECILIA'), findsOneWidget);
      expect(
        find.text(
          'Chúa Chiên Lành Từ Bi Thương Xót Dân Ngài Muôn Đời Không Bao Giờ Cạn',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Trình Phát Audio Mẫu'), 180);
      await tester.pumpAndSettle();
      expect(find.text('Soprano'), findsWidgets);
      // Bass has no sampleAudio material so its audio part selector must not appear.
      expect(find.byKey(const ValueKey('audio-part-bass')), findsNothing);

      // Switching part selector updates the selected track cleanly.
      final altoSelector = find.byKey(const ValueKey('audio-part-audio-alto'));
      await tester.ensureVisible(altoSelector);
      await tester.tap(altoSelector);
      await tester.pumpAndSettle();
      expect(find.text('Alto'), findsOneWidget);

      // Scroll down to separated score, assignment, and director notes sections.
      await tester.scrollUntilVisible(find.text('Bản Phổ Tương Tác'), 220);
      await tester.pumpAndSettle();
      expect(find.text('Bản Phổ Tương Tác'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Phân Công & Tài Liệu'), 220);
      await tester.pumpAndSettle();
      expect(find.text('Phân Công & Tài Liệu'), findsOneWidget);

      final noteFinder = find.text('Ghi chú & Dặn dò');
      await tester.scrollUntilVisible(noteFinder, 220);
      await tester.pumpAndSettle();
      expect(noteFinder, findsOneWidget);
      expect(
        find.text('Hát rõ phụ âm cuối và lấy hơi trước điệp khúc.'),
        findsOneWidget,
      );

      // Verify interactive score flow works.
      final openScoreBtn = find.text('Mở trình phát nốt');
      await tester.scrollUntilVisible(openScoreBtn, -200);
      await tester.pumpAndSettle();
      await tester.tap(openScoreBtn);
      await tester.pumpAndSettle();
      expect(find.text('Score score-14'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify bottom CTA bar links to practice submission.
      final practiceCta = find.text('Tập hát & Thu âm');
      expect(practiceCta, findsOneWidget);
      await tester.tap(practiceCta);
      await tester.pumpAndSettle();
      expect(find.text('Practice assign-14'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SongDetailScreen omits empty notes, audio card, and assignment CTA when data is missing at 390dp',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const SongDetailScreen(songId: 'song-minimal-14'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            musicRepositoryProvider.overrideWithValue(
              _MinimalSongDetailRepository(),
            ),
            practiceRepositoryProvider.overrideWithValue(_EmptyPracticeRepo()),
            publicAppSettingsProvider.overrideWith(
              (_) async => const PublicAppSettings(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bài Ca Đơn Giản'), findsOneWidget);
      expect(find.text('Ghi chú & Dặn dò'), findsNothing);
      expect(find.text('Tập hát & Thu âm'), findsNothing);
      expect(find.text('Trình Phát Audio Mẫu'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'MusicLibraryScreen Stitch 15 shows honest paged counts, real practice feedback/deadline, card flows, and omits unsupported actions at 360dp',
    (tester) async {
      _stubAudioChannels(tester);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);

      final repo = _StitchLibraryRepository();
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          musicRepositoryProvider.overrideWithValue(repo),
          practiceRepositoryProvider.overrideWithValue(_StitchPracticeRepo()),
          profileRepositoryProvider.overrideWithValue(_StitchProfileRepo()),
          publicAppSettingsProvider.overrideWith(
            (_) async =>
                const PublicAppSettings(choirName: 'Ca đoàn Thánh Tâm'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const MusicLibraryScreen()),
          GoRoute(
            path: '/interactive-score/:id',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Score ${state.pathParameters['id']}'),
            ),
          ),
          GoRoute(
            path: '/music-material/:id',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Material ${state.pathParameters['id']}'),
            ),
          ),
          GoRoute(
            path: '/practice-detail/:id',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Practice ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await container
          .read(musicLibraryProvider.notifier)
          .refresh(materialsTab: true);
      await tester.pumpAndSettle();

      expect(find.text('Kho Bài Hát Chung'), findsOneWidget);
      expect(find.text('Tài liệu học của tôi'), findsWidgets);
      expect(find.text('CA ĐOÀN THÁNH TÂM'), findsOneWidget);
      expect(
        find.text(
          'Đang hiển thị 2/7 tài liệu • Số liệu chi tiết tính trên phần đã tải',
        ),
        findsOneWidget,
      );
      expect(find.text('Bè: Soprano'), findsOneWidget);

      // Unsupported Stitch controls must NOT be present.
      expect(find.text('Tải hết'), findsNothing);
      expect(find.text('Solo'), findsNothing);
      expect(find.text('Mute'), findsNothing);

      // Scroll to interactive score card & verify practice feedback + action buttons.
      final scoreBtn = find.text('Mở bản nhạc tương tác');
      await tester.scrollUntilVisible(
        scoreBtn,
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Giữ hơi đều ở ô nhịp 16'), findsOneWidget);
      expect(find.text('Thu nộp bài'), findsOneWidget);

      await tester.tap(scoreBtn);
      await tester.pumpAndSettle();
      expect(find.text('Score mat-score'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(container.read(musicLibraryProvider).materialsTab, isTrue);

      // Verify practice submission CTA opens practice detail.
      await tester.tap(find.text('Thu nộp bài'));
      await tester.pumpAndSettle();
      expect(find.text('Practice assign-14'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'MusicLibraryScreen Stitch 15 preserves filters and supports switching tabs at 390dp',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      addTearDown(session.dispose);

      final repo = _StitchLibraryRepository();
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          musicRepositoryProvider.overrideWithValue(repo),
          practiceRepositoryProvider.overrideWithValue(_EmptyPracticeRepo()),
          profileRepositoryProvider.overrideWithValue(_StitchProfileRepo()),
          publicAppSettingsProvider.overrideWith(
            (_) async => const PublicAppSettings(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const MusicLibraryScreen()),
          GoRoute(
            path: '/music-material/:id',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Material ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Switch from Kho Bài Hát Chung to Tài liệu học của tôi via UI tab.
      await tester.tap(find.text('Tài liệu học của tôi'));
      await tester.pumpAndSettle();
      expect(container.read(musicLibraryProvider).materialsTab, isTrue);

      // Filter by SheetMusic and Learned progress.
      await tester.tap(find.text('Bản nhạc phổ'));
      await tester.pumpAndSettle();
      final learnedTab = find.widgetWithText(InkWell, 'Đã thuộc').first;
      await tester.ensureVisible(learnedTab);
      await tester.tap(learnedTab);
      await tester.pumpAndSettle();

      expect(
        container.read(musicLibraryProvider).materialType,
        music.MaterialType.sheetMusic,
      );
      expect(
        container.read(musicLibraryProvider).learningStatus,
        music.LearningStatus.learned,
      );

      final openPdf = find.text('Mở bản phổ');
      await tester.scrollUntilVisible(
        openPdf,
        180,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.tap(openPdf);
      await tester.pumpAndSettle();
      expect(find.text('Material mat-pdf'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      final afterBack = container.read(musicLibraryProvider);
      expect(afterBack.materialsTab, isTrue);
      expect(afterBack.materialType, music.MaterialType.sheetMusic);
      expect(afterBack.learningStatus, music.LearningStatus.learned);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'MusicLibraryScreen Kho Bài Hát Chung shares Tài liệu học layout while keeping library cover at 360dp',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          musicRepositoryProvider.overrideWithValue(_PagedSongRepo()),
          practiceRepositoryProvider.overrideWithValue(_StitchPracticeRepo()),
          publicAppSettingsProvider.overrideWith(
            (_) async => const PublicAppSettings(choirName: 'Ca đoàn Cecilia'),
          ),
        ],
      );

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const MusicLibraryScreen()),
          GoRoute(
            path: '/song-detail/:id',
            builder: (_, state) => Scaffold(
              appBar: AppBar(),
              body: Text('Song ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thư viện thánh ca'), findsOneWidget);
      expect(find.text('CA ĐOÀN CECILIA'), findsOneWidget);
      expect(find.text('Kho Bài Hát Chung'), findsOneWidget);
      expect(find.text('Tài liệu học của tôi'), findsOneWidget);
      expect(find.byTooltip('Tìm kiếm'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Bộ lọc'), findsOneWidget);

      // Keeps Kho Bài Hát Chung artwork while matching full-bleed hero + overview layout.
      final heroArt = tester.widget<MemberChoirArt>(
        find.byType(MemberChoirArt),
      );
      expect(heroArt.artwork, MemberChoirArtwork.library);
      expect(find.text('Bài hát và bản phổ'), findsOneWidget);
      expect(
        find.text(
          'Đang hiển thị 2/5 bài hát • Số liệu chi tiết tính trên phần đã tải',
        ),
        findsOneWidget,
      );
      expect(find.text('Tất cả mùa'), findsOneWidget);

      final songCard = find.text('Bài hát dài thử nghiệm Kho Bài Hát Chung');
      await tester.scrollUntilVisible(
        songCard,
        180,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.ensureVisible(songCard);
      await tester.pumpAndSettle();
      await tester.tap(songCard);
      await tester.pumpAndSettle();
      expect(find.text('Song song-stitch-14'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'MusicLibraryScreen uses unified top header search with validation and 1-char search across tabs at 360dp',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      final repo = _SearchableLibraryRepo();

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          musicRepositoryProvider.overrideWithValue(repo),
          practiceRepositoryProvider.overrideWithValue(_StitchPracticeRepo()),
          publicAppSettingsProvider.overrideWith(
            (_) async => const PublicAppSettings(choirName: 'Ca đoàn Cecilia'),
          ),
        ],
      );

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const MusicLibraryScreen()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final verticalList = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      );

      expect(find.byType(TextField), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Bài hát dài thử nghiệm Kho Bài Hát Chung'),
        180,
        scrollable: verticalList,
      );
      expect(
        find.text('Bài hát dài thử nghiệm Kho Bài Hát Chung'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const ValueKey('library-header-search'));
      expect(searchField, findsOneWidget);
      expect(
        find.text('Gõ từ 1 ký tự để hiển thị bài hát cần tìm'),
        findsOneWidget,
      );

      await tester.enterText(searchField, '   ');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(
        find.text('Vui lòng nhập ít nhất 1 ký tự (không chỉ khoảng trắng).'),
        findsOneWidget,
      );
      expect(repo.songKeywords, ['']);

      await tester.enterText(searchField, 'V');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(repo.songKeywords.last, 'V');
      await tester.scrollUntilVisible(
        find.text('Thánh Vịnh Đáp Ca'),
        180,
        scrollable: verticalList,
      );
      expect(find.text('Thánh Vịnh Đáp Ca'), findsOneWidget);
      expect(
        find.text('Bài hát dài thử nghiệm Kho Bài Hát Chung'),
        findsNothing,
      );

      await tester.tap(find.text('Tài liệu học của tôi'));
      await tester.pumpAndSettle();
      expect(searchField, findsOneWidget);
      expect(repo.materialKeywords.last, 'V');
      final matchingMaterial = find.text(
        'Bản phổ tương tác bài Thánh Vịnh Tôn Vinh Đấng Cứu Thế Cho Bốn Bè Hợp Xướng',
      );
      await tester.scrollUntilVisible(
        matchingMaterial,
        180,
        scrollable: verticalList,
      );
      expect(matchingMaterial, findsOneWidget);
      expect(find.text('Tổng phổ PDF Lễ Tro - Ca Đoàn'), findsNothing);

      await tester.tap(find.byTooltip('Đóng tìm kiếm'));
      await tester.pumpAndSettle();
      expect(searchField, findsNothing);
      expect(repo.materialKeywords.last, '');
      await tester.scrollUntilVisible(
        find.text('Tổng phổ PDF Lễ Tro - Ca Đoàn'),
        180,
        scrollable: verticalList,
      );
      expect(find.text('Tổng phổ PDF Lễ Tro - Ca Đoàn'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'MusicLibraryScreen Tài liệu học của tôi validates empty submit and filters with 1 char at 390dp',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      final repo = _SearchableLibraryRepo();

      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          musicRepositoryProvider.overrideWithValue(repo),
          practiceRepositoryProvider.overrideWithValue(_StitchPracticeRepo()),
          publicAppSettingsProvider.overrideWith(
            (_) async => const PublicAppSettings(choirName: 'Ca đoàn Cecilia'),
          ),
        ],
      );

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const MusicLibraryScreen()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tài liệu học của tôi'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();
      final searchField = find.byKey(const ValueKey('library-header-search'));
      expect(searchField, findsOneWidget);
      expect(
        find.text('Gõ từ 1 ký tự để hiển thị tài liệu cần tìm'),
        findsOneWidget,
      );

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        find.text('Vui lòng nhập ít nhất 1 ký tự để tìm kiếm.'),
        findsOneWidget,
      );
      expect(repo.materialKeywords, ['']);

      await tester.enterText(searchField, 'L');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(repo.materialKeywords.last, 'L');
      expect(find.text('Tổng phổ PDF Lễ Tro - Ca Đoàn'), findsOneWidget);
      expect(find.text('Audio hướng dẫn bè Soprano'), findsNothing);

      await tester.tap(find.byTooltip('Xóa từ khóa'));
      await tester.pumpAndSettle();
      expect(searchField, findsOneWidget);
      expect(
        find.text('Gõ từ 1 ký tự để hiển thị tài liệu cần tìm'),
        findsOneWidget,
      );
      expect(repo.materialKeywords.last, '');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
      session.dispose();
    },
  );
}

void _stubAudioChannels(WidgetTester tester) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (_) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global/events'),
    (_) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async {
      if (call.method == 'create') {
        final id = (call.arguments as Map)['playerId'] as String;
        messenger.setMockMethodCallHandler(
          MethodChannel('xyz.luan/audioplayers/events/$id'),
          (_) async => null,
        );
      }
      return null;
    },
  );
}

class _StitchSongDetailRepository extends MockMusicRepositoryImpl {
  @override
  Future<SongListItem?> getSongDetail(String songId) async => SongListItem(
    id: songId,
    slotName: 'Ca Nhập Lễ',
    title:
        'Chúa Chiên Lành Từ Bi Thương Xót Dân Ngài Muôn Đời Không Bao Giờ Cạn',
    composer: 'Lm. Kim Long',
    tone: 'Sol Trưởng (G)',
    tempo: '68 BPM',
    sheetMusicUrl: '',
    audioSampleUrl: '',
    lyrics: 'Lạy Chúa xin thương xót.',
    learningStatus: music.LearningStatus.needsPractice,
    note: 'Hát rõ phụ âm cuối và lấy hơi trước điệp khúc.',
    classification: const music.SongClassificationDto(
      songId: 'song-stitch-14',
      liturgicalSeasons: [
        music.SongClassificationSummaryDto(id: 's1', name: 'Mùa Phục Sinh'),
      ],
      massTypes: [
        music.SongClassificationSummaryDto(
          id: 'm1',
          name: 'Thánh lễ Chúa Nhật',
        ),
      ],
      vocalRequirements: [
        music.SongVocalRequirementDto(
          skillId: 'v1',
          skillName: 'Soprano',
          isMandatory: true,
        ),
        music.SongVocalRequirementDto(
          skillId: 'v2',
          skillName: 'Alto',
          isMandatory: true,
        ),
      ],
    ),
    materials: const [
      music.MusicMaterialDto(
        id: 'audio-sop',
        songId: 'song-stitch-14',
        materialType: music.MaterialType.sampleAudio,
        title: 'Audio mẫu bè Soprano',
        targetSkillName: 'Soprano',
        fileName: 'sop.mp3',
        fileUrl: 'https://example.invalid/sop.mp3',
        createdAt: '2026-10-10T00:00:00Z',
      ),
      music.MusicMaterialDto(
        id: 'audio-alto',
        songId: 'song-stitch-14',
        materialType: music.MaterialType.sampleAudio,
        title: 'Audio mẫu bè Alto',
        targetSkillName: 'Alto',
        fileName: 'alto.mp3',
        fileUrl: 'https://example.invalid/alto.mp3',
        createdAt: '2026-10-10T00:00:00Z',
      ),
      music.MusicMaterialDto(
        id: 'score-14',
        songId: 'song-stitch-14',
        materialType: music.MaterialType.interactiveScore,
        title: 'Bản phổ tương tác 4 bè',
        fileName: 'score.mxl',
        fileUrl: '',
        createdAt: '2026-10-10T00:00:00Z',
      ),
      music.MusicMaterialDto(
        id: 'sheet-14',
        songId: 'song-stitch-14',
        materialType: music.MaterialType.sheetMusic,
        title: 'Tổng phổ PDF 4 bè',
        fileName: 'sheet.pdf',
        fileSizeBytes: 2457600,
        fileUrl: 'https://example.invalid/sheet.pdf',
        createdAt: '2026-10-10T00:00:00Z',
      ),
    ],
  );
}

class _MinimalSongDetailRepository extends MockMusicRepositoryImpl {
  @override
  Future<SongListItem?> getSongDetail(String songId) async =>
      const SongListItem(
        id: 'song-minimal-14',
        slotName: '',
        title: 'Bài Ca Đơn Giản',
        composer: '',
        tone: '',
        tempo: '',
        sheetMusicUrl: '',
        audioSampleUrl: '',
        lyrics: '',
        learningStatus: music.LearningStatus.notStarted,
      );
}

class _StitchLibraryRepository extends MockMusicRepositoryImpl {
  static final _allMaterials = [
    const music.MusicMaterialDetailDto(
      id: 'mat-score',
      songId: 'song-stitch-14',
      materialType: music.MaterialType.interactiveScore,
      title: 'Bản phổ tương tác bài Thánh Vịnh Tôn Vinh Đấng Cứu Thế Cho Bốn Bè Hợp Xướng',
      fileName: 'score.mxl',
      targetSkillName: 'Soprano',
      fileUrl: '',
      createdAt: '2026-10-15T00:00:00Z',
      learningStatus: music.LearningStatus.needsPractice,
    ),
    const music.MusicMaterialDetailDto(
      id: 'mat-pdf',
      songId: 'song-02',
      materialType: music.MaterialType.sheetMusic,
      title: 'Tổng phổ PDF Lễ Tro - Ca Đoàn',
      fileName: 'sheet.pdf',
      fileSizeBytes: 1572864,
      targetSkillName: 'Hợp xướng',
      fileUrl: 'https://example.invalid/sheet.pdf',
      createdAt: '2026-10-15T00:00:00Z',
      learningStatus: music.LearningStatus.learned,
    ),
    const music.MusicMaterialDetailDto(
      id: 'mat-audio',
      songId: 'song-03',
      materialType: music.MaterialType.sampleAudio,
      title: 'Audio hướng dẫn bè Soprano',
      fileName: 'audio.mp3',
      targetSkillName: 'Soprano',
      fileUrl: 'https://example.invalid/audio.mp3',
      createdAt: '2026-10-15T00:00:00Z',
      learningStatus: music.LearningStatus.notStarted,
    ),
  ];

  @override
  Future<PagedList<music.MusicMaterialDetailDto>> getMyMaterialsPage(
    music.SearchMusicMaterialsRequest request,
  ) async {
    var filtered = _allMaterials.where((item) {
      if (request.materialType != null &&
          item.materialType != request.materialType) {
        return false;
      }
      if (request.learningStatus != null &&
          item.learningStatus != request.learningStatus) {
        return false;
      }
      if (request.keyword != null && request.keyword!.trim().isNotEmpty) {
        final q = request.keyword!.trim().toLowerCase();
        if (!item.title.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
    final unfiltered =
        request.materialType == null &&
        request.learningStatus == null &&
        (request.keyword == null || request.keyword!.isEmpty);
    if (unfiltered) {
      filtered = filtered.take(2).toList();
    }
    return PagedList(
      items: filtered,
      pageNumber: request.pageNumber,
      pageSize: request.pageSize,
      totalCount: unfiltered ? 7 : filtered.length,
      totalPages: unfiltered ? 4 : 1,
      hasPreviousPage: false,
      hasNextPage: unfiltered,
    );
  }
}

class _StitchPracticeRepo extends MockPracticeRepositoryImpl {
  @override
  Future<PagedList<PracticeAssignment>> getAssignmentsPaged({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async => PagedList(
    items: [
      PracticeAssignment(
        id: 'assign-14',
        title: 'Thu âm câu đáp Soprano',
        songTitle: 'Chúa Chiên Lành',
        songId: 'song-stitch-14',
        instruction: 'Giữ nhịp 68 BPM ở điệp khúc.',
        dueDate: DateTime(2026, 11, 20),
        vocalPart: 'Soprano',
        status: PracticeStatus.needsRevision,
        feedbackComment: 'Giữ hơi đều ở ô nhịp 16',
        materials: const [
          (
            id: 'mat-score',
            title: 'Bản phổ tương tác',
            type: music.MaterialType.interactiveScore,
          ),
        ],
      ),
    ],
    pageNumber: 1,
    pageSize: 50,
    totalCount: 1,
    totalPages: 1,
    hasPreviousPage: false,
    hasNextPage: false,
  );
}

class _EmptyPracticeRepo extends MockPracticeRepositoryImpl {
  @override
  Future<PagedList<PracticeAssignment>> getAssignmentsPaged({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async => const PagedList(
    items: [],
    pageNumber: 1,
    pageSize: 50,
    totalCount: 0,
    totalPages: 0,
    hasPreviousPage: false,
    hasNextPage: false,
  );
}

class _StitchProfileRepo extends MockProfileRepositoryImpl {
  @override
  Future<PagedList<MemberSkill>> getSkillsPaged({
    String? status,
    int pageNumber = 1,
    int pageSize = 50,
  }) async => const PagedList(
    items: [
      MemberSkill(
        id: 'sk-sop',
        name: 'Soprano',
        categoryName: 'Kỹ năng thanh nhạc',
        status: SkillApprovalStatus.approved,
      ),
    ],
    pageNumber: 1,
    pageSize: 50,
    totalCount: 1,
    totalPages: 1,
    hasPreviousPage: false,
    hasNextPage: false,
  );
}

class _PagedSongRepo extends MockMusicRepositoryImpl {
  @override
  Future<PagedList<music.SongDto>> getSongsPage(
    music.SearchSongsRequest request,
  ) async => const PagedList(
    items: [
      music.SongDto(
        id: 'song-stitch-14',
        title: 'Bài hát dài thử nghiệm Kho Bài Hát Chung',
        composer: 'Lm. Kim Long',
        musicalKey: 'G',
        materialCounts: {
          music.MaterialType.sheetMusic: 1,
          music.MaterialType.interactiveScore: 1,
        },
      ),
      music.SongDto(
        id: 'song-02',
        title: 'Thánh Vịnh Đáp Ca',
        composer: 'Thành Tâm',
      ),
    ],
    pageNumber: 1,
    pageSize: 20,
    totalCount: 5,
    totalPages: 2,
    hasPreviousPage: false,
    hasNextPage: true,
  );
}

class _SearchableLibraryRepo extends _StitchLibraryRepository {
  final List<String> songKeywords = [];
  final List<String> materialKeywords = [];

  static const _songs = [
    music.SongDto(
      id: 'song-stitch-14',
      title: 'Bài hát dài thử nghiệm Kho Bài Hát Chung',
      composer: 'Lm. Kim Long',
      musicalKey: 'G',
      materialCounts: {
        music.MaterialType.sheetMusic: 1,
        music.MaterialType.interactiveScore: 1,
      },
    ),
    music.SongDto(
      id: 'song-02',
      title: 'Thánh Vịnh Đáp Ca',
      composer: 'Thành Tâm',
    ),
  ];

  @override
  Future<PagedList<music.SongDto>> getSongsPage(
    music.SearchSongsRequest request,
  ) async {
    final keyword = (request.keyword ?? '').trim();
    songKeywords.add(keyword);
    final filtered = keyword.isEmpty
        ? _songs
        : _songs.where((song) {
            final q = keyword.toLowerCase();
            return song.title.toLowerCase().contains(q) ||
                (song.composer ?? '').toLowerCase().contains(q);
          }).toList();
    return PagedList(
      items: filtered,
      pageNumber: request.pageNumber,
      pageSize: request.pageSize,
      totalCount: filtered.length,
      totalPages: 1,
      hasPreviousPage: false,
      hasNextPage: false,
    );
  }

  @override
  Future<PagedList<music.MusicMaterialDetailDto>> getMyMaterialsPage(
    music.SearchMusicMaterialsRequest request,
  ) async {
    materialKeywords.add((request.keyword ?? '').trim());
    return super.getMyMaterialsPage(request);
  }
}
