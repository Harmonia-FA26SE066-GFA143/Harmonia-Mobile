import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/network/api_client.dart';
import 'package:harmonia_mobile/core/errors/app_exceptions.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/practice/data/practice_api_service.dart';
import 'package:harmonia_mobile/features/practice/data/practice_models.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';
import 'package:harmonia_mobile/features/staff_workspace/data/staff_operations_api.dart';

class PermissionApi extends PracticeApiService {
  final Map<String, dynamic> assignment;

  PermissionApi(this.assignment)
    : super(
        ApiClient(
          storage: SecureStorageService(),
          sessionManager: SessionManager(SecureStorageService()),
          customDio: Dio(),
        ),
      );

  @override
  Future<Map<String, dynamic>> getAssignmentDetail(String id) async =>
      assignment;

  @override
  Future<Map<String, dynamic>> getMyAssignments({
    bool? isOpen,
    String? status,
    bool? hasSubmission,
    int pageNumber = 1,
    int pageSize = 50,
  }) async => {
    'items': [assignment],
    'totalCount': 1,
  };
}

class UploadStorage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'fixture-token';
}

class UploadSession extends SessionManager {
  UploadSession(super.storage);
  int epoch = 0;
  @override
  int get sessionEpoch => epoch;
}

class UploadAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    if (options.path.endsWith('/score')) {
      return ResponseBody.fromString(
        '{"score":80}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('', 201);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'submission and draft score send only supported audio MIME types',
    () async {
      final temp = Directory.systemTemp.createTempSync(
        'harmonia-audio-format-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final storage = UploadStorage();
      final session = UploadSession(storage);
      addTearDown(session.dispose);
      final adapter = UploadAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final client = ApiClient(
        storage: storage,
        sessionManager: session,
        customDio: dio,
      );
      final practice = PracticeApiService(client);
      final staff = StaffOperationsApi(client, session.sessionEpoch);

      for (final (extension, contentType) in [
        ('MP3', 'audio/mpeg'),
        ('m4a', 'audio/mp4'),
        ('wav', 'audio/wav'),
      ]) {
        final name = 'fixture.$extension';
        final file = File('${temp.path}/$name')..writeAsBytesSync([1, 2, 3]);
        await practice.submitRecording(
          assignmentId: 'fixture',
          filePath: file.path,
          durationSeconds: 5,
        );
        await staff.scoreDraft('fixture', file.path);
        for (final request in adapter.requests.reversed.take(2)) {
          final part = (request.data as FormData).files.single;
          expect(part.key, 'file');
          expect(part.value.filename, name);
          expect(part.value.contentType.toString(), contentType);
        }
      }

      final other = File('${temp.path}/fixture.ogg')
        ..writeAsBytesSync([1, 2, 3]);
      await expectLater(
        practice.submitRecording(
          assignmentId: 'fixture',
          filePath: other.path,
          durationSeconds: 5,
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        staff.scoreDraft('fixture', other.path),
        throwsA(isA<AppException>()),
      );
      expect(adapter.requests, hasLength(6));
    },
  );

  for (final changeSession in [false, true]) {
    test(
      'upload remains bound to its original session: change=$changeSession',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'harmonia-upload-permission-',
        );
        addTearDown(() => temp.deleteSync(recursive: true));
        final file = File('${temp.path}/fixture.m4a')
          ..writeAsBytesSync(List.filled(64, 0));
        final storage = UploadStorage();
        final session = UploadSession(storage);
        addTearDown(session.dispose);
        final adapter = UploadAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        addTearDown(() => dio.close(force: true));
        final api = PracticeApiService(
          ApiClient(storage: storage, sessionManager: session, customDio: dio),
        );
        final pending = api.submitRecording(
          assignmentId: 'fixture',
          filePath: file.path,
          durationSeconds: 2,
        );
        if (changeSession) {
          session.epoch++;
          await expectLater(pending, throwsA(isA<AppException>()));
          expect(adapter.requests, isEmpty);
        } else {
          await pending;
          expect(adapter.requests, hasLength(1));
          expect(adapter.requests.single.extra['expectedSessionEpoch'], 0);
        }
      },
    );
  }
  for (final fields in <Map<String, dynamic>>[
    {'canSubmit': true, 'isOverdue': true},
    {
      'canSubmit': false,
      'cannotSubmitReason': 'PRACTICE_SUBMISSION_ALREADY_PASSED',
      'latestSubmissionStatus': 'Passed',
    },
    {
      'canSubmit': false,
      'cannotSubmitReason': 'PRACTICE_SUBMISSION_PAST_DUE',
      'isOverdue': true,
    },
    {'canSubmit': false, 'cannotSubmitReason': 'FUTURE_REASON'},
    {},
    {'canSubmit': 'true', 'cannotSubmitReason': 123},
  ]) {
    test(
      'list and detail retain server submission permission: $fields',
      () async {
        final repo = PracticeRepositoryImpl(
          apiService: PermissionApi({
            'id': 'assignment-test',
            'title': 'Bài tập kiểm thử',
            'dueDate': '2000-01-01T00:00:00Z',
            ...fields,
          }),
        );
        final list = await repo.getAssignments();
        final detail = await repo.getAssignmentDetail('assignment-test');
        expect(detail, isNotNull);
        for (final item in [list.single, detail!]) {
          expect(
            item.canSubmit,
            fields['canSubmit'] is bool ? fields['canSubmit'] : isNull,
          );
          expect(
            item.cannotSubmitReason,
            fields['cannotSubmitReason'] is String
                ? fields['cannotSubmitReason']
                : isNull,
          );
          // Local submission updates must not discard the server capability.
          final updated = item.copyWith(status: PracticeStatus.submitted);
          expect(updated.canSubmit, item.canSubmit);
          expect(updated.cannotSubmitReason, item.cannotSubmitReason);
        }
      },
    );
  }
}
