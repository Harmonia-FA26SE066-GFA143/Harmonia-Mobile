import 'support/fake_music_repository.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harmonia_mobile/features/music/presentation/music_library_screen.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart' as music;
import 'package:harmonia_mobile/features/music/data/music_repository.dart';
import 'package:harmonia_mobile/features/music/presentation/music_material_screen.dart';
import 'package:harmonia_mobile/features/music/presentation/music_library_notifier.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';

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

void main() {
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
    await tester.tap(find.text('Bản nhạc B'));
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
}
