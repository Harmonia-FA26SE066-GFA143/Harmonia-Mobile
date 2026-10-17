import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/music/data/music_api_service.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart';
import 'package:harmonia_mobile/features/music/data/music_repository.dart';
import 'package:harmonia_mobile/features/notifications/data/notification_dto.dart';

class DetailApi extends MusicApiService {
  bool offline = false;
  DetailApi(super.client);
  @override
  Future<SongDto> getSongById(String id) async {
    if (offline) throw const NetworkException();
    return SongDto(id: id, title: 'Bài hát chưa có thông tin');
  }

  @override
  Future<SongClassificationDto> getSongClassification(String id) async =>
      SongClassificationDto(songId: id);
  @override
  Future<PagedList<MusicMaterialDetailDto>> getMyMaterials(
    SearchMusicMaterialsRequest request,
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
  Future<PagedList<MusicMaterialDto>> getMaterialsBySong(
    String songId, {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DetailApi api;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService();
    api = DetailApi(
      ApiClient(
        storage: storage,
        sessionManager: SessionManager(storage),
        customDio: Dio(),
      ),
    );
  });
  test(
    'song detail preserves connection errors instead of reporting missing data',
    () async {
      api.offline = true;
      await expectLater(
        MusicRepositoryImpl(apiService: api).getSongDetail('song-a'),
        throwsA(isA<NetworkException>()),
      );
    },
  );
  test('song detail does not fabricate composer key or tempo', () async {
    final song = await MusicRepositoryImpl(apiService: api)
        .getSongDetail('song-a');
    expect(song!.composer, isEmpty);
    expect(song.tone, isEmpty);
    expect(song.tempo, isEmpty);
  });
}
