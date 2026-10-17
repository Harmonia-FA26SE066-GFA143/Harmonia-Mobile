import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart';
import 'package:harmonia_mobile/features/music/data/music_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'approved song list reloads on session change and ignores old results',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final session = SessionManager(SecureStorageService());
      await session.markAuthenticated(role: 'ChoirMember');
      final repository = _DeferredMusicRepository();
      final container = ProviderContainer(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          musicRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final provider = eventApprovedSongListProvider('event-a');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(() {
        subscription.close();
        container.dispose();
        session.dispose();
      });
      expect(repository.requests, hasLength(1));

      await session.markAuthenticated(role: 'ChoirMember');
      await container.pump();
      expect(repository.requests, hasLength(2));

      final currentResult = container.read(provider.future);
      repository.requests[1].complete(
        const SongListDto(
          id: 'song-list-b',
          eventId: 'event-a',
          version: 2,
          status: 'Approved',
          items: [],
        ),
      );
      expect((await currentResult)?.id, 'song-list-b');

      repository.requests[0].complete(
        const SongListDto(
          id: 'song-list-a',
          eventId: 'event-a',
          version: 1,
          status: 'Approved',
          items: [],
        ),
      );
      await container.pump();
      expect(container.read(provider).requireValue?.id, 'song-list-b');
    },
  );
}

class _DeferredMusicRepository implements MusicRepository {
  final requests = <Completer<SongListDto?>>[];

  @override
  Future<SongListDto?> getApprovedSongList(String eventId) {
    final request = Completer<SongListDto?>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
