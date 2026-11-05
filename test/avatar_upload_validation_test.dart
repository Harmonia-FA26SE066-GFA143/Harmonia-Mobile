import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/profile/data/member_profile_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  late MemberProfileApiService service;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('avatar-upload-test');
    final storage = SecureStorageService();
    service = MemberProfileApiService(
      ApiClient(
        storage: storage,
        sessionManager: SessionManager(storage),
        customDio: Dio(),
      ),
    );
  });

  tearDown(() => tempDirectory.delete(recursive: true));

  test(
    'rejects avatar images larger than 2 MB before calling the API',
    () async {
      final image = File('${tempDirectory.path}/avatar.jpg');
      await image.writeAsBytes(List<int>.filled(2 * 1024 * 1024 + 1, 0));

      await expectLater(
        service.updateMyAvatar(image.path),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'AVATAR_FILE_TOO_LARGE',
          ),
        ),
      );
    },
  );

  test(
    'rejects unsupported avatar extensions before calling the API',
    () async {
      final image = File('${tempDirectory.path}/avatar.gif');
      await image.writeAsBytes([1, 2, 3]);

      await expectLater(
        service.updateMyAvatar(image.path),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'AVATAR_FILE_TYPE_NOT_ALLOWED',
          ),
        ),
      );
    },
  );
}
