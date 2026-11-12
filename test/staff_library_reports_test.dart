import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/app/router/role_routes.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/features/music/data/music_dto.dart';
import 'package:harmonia_mobile/features/staff_workspace/data/staff_documents.dart';

import 'auth_account_session_test.dart' show jsonResponse;
import 'staff_operations_test.dart' show makeApi;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('the song workspace is available only to a choir director', () {
    for (final role in [null, ...MobileRole.values]) {
      expect(
        roleAllowsRoute(role, Uri.parse('/staff-library')),
        role == MobileRole.choirDirector,
      );
    }
  });

  test(
    'song changes use the song resource and preserve classification counts',
    () async {
      final api = makeApi((request) {
        switch (request.method) {
          case 'POST':
            expect(request.path, '/api/songs');
            expect(request.data['title'], 'Thánh ca');
            expect(request.data.containsKey('id'), isFalse);
            return jsonResponse(200, {'id': 'song', ...request.data});
          case 'GET':
            expect(request.path, '/api/songs/song/classification');
            return jsonResponse(200, {
              'songId': 'song',
              'liturgicalSlots': [
                {'id': 'slot', 'name': 'Hiệp lễ'},
              ],
              'vocalRequirements': [
                {
                  'skillId': 'vocal',
                  'skillName': 'Bè nam',
                  'isMandatory': true,
                  'requiredCount': 3,
                },
              ],
            });
          case 'PUT':
            expect(request.path, '/api/songs/song/classification');
            expect(request.data['liturgicalSlotIds'], ['slot']);
            expect(request.data['vocalRequirements'], [
              {'skillId': 'vocal', 'isMandatory': true, 'requiredCount': 3},
            ]);
            return jsonResponse(200, {});
          default:
            throw StateError(request.method);
        }
      });

      final song = await api.saveSong(const SongDto(id: '', title: 'Thánh ca'));
      final classification = await api.songClassification(song.id);
      await api.saveSongClassification(song.id, {
        'liturgicalSlotIds': classification.liturgicalSlots
            .map((slot) => slot.id)
            .toList(),
        'vocalRequirements': [
          for (final row in classification.vocalRequirements)
            {
              'skillId': row.skillId,
              'isMandatory': row.isMandatory,
              'requiredCount': row.requiredCount,
            },
        ],
      });
    },
  );

  test(
    'files use the multipart contracts and retain the selected filename',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'harmonia-staff-test-',
      );
      addTearDown(() async {
        for (final name in ['score.pdf', 'audio.m4a']) {
          await File('${directory.path}/$name').delete();
        }
        await directory.delete();
      });
      final score = await File('${directory.path}/score.pdf')
          .writeAsBytes([37, 80, 68, 70]);
      final audio = await File('${directory.path}/audio.m4a')
          .writeAsBytes([0, 1, 2]);
      final paths = <String>[];
      final api = makeApi((request) {
        paths.add('${request.method} ${request.path}');
        if (request.method == 'DELETE') return ResponseBody.fromString('', 204);

        final form = request.data as FormData;
        final fields = Map.fromEntries(form.fields);
        expect(form.files.single.key, 'file');
        switch (request.path) {
          case '/api/music-materials':
            expect(fields, {
              'songId': 'song',
              'title': 'Bản nhạc',
              'materialType': 'SheetMusic',
              'targetSkillId': 'skill',
            });
            expect(form.files.single.value.filename, 'ban-nhac.pdf');
          case '/api/music-materials/material/file':
            expect(fields, {'resetProgress': 'true'});
            expect(form.files.single.value.filename, 'ban-nhac.pdf');
          case '/api/rehearsals/rehearsal/recordings':
            expect(fields, {'title': 'Lượt 1', 'songId': 'song'});
            expect(form.files.single.value.filename, 'buoi-tap.m4a');
        }
        return jsonResponse(200, {});
      });
      final document = StaffDocument(score.path, 'ban-nhac.pdf');
      await api.uploadMaterial(
        songId: 'song',
        type: MaterialType.sheetMusic,
        title: 'Bản nhạc',
        targetSkillId: 'skill',
        file: document,
      );
      await api.replaceMaterialFile('material', document, resetProgress: true);
      await api.uploadRehearsalRecording(
        'rehearsal',
        StaffDocument(audio.path, 'buoi-tap.m4a'),
        title: 'Lượt 1',
        songId: 'song',
      );
      await api.deleteRehearsalRecording('rehearsal', 'recording');
      expect(paths, [
        'POST /api/music-materials',
        'PUT /api/music-materials/material/file',
        'POST /api/rehearsals/rehearsal/recordings',
        'DELETE /api/rehearsals/rehearsal/recordings/recording',
      ]);
    },
  );

  test(
    'report export preserves binary data and the requested format',
    () async {
      const bytes = [37, 80, 68, 70, 0, 255];
      final api = makeApi((request) {
        expect(request.path, '/api/reports/export');
        expect(request.queryParameters, {
          'type': 'Participation',
          'format': 'Pdf',
          'fromDate': '2026-11-01',
          'choirId': 'choir',
        });
        return ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            Headers.contentTypeHeader: ['application/pdf'],
          },
        );
      });
      expect(
        await api.exportReport('Participation', 'Pdf', {
          'fromDate': '2026-11-01',
          'choirId': 'choir',
        }),
        bytes,
      );
    },
  );

  test('saving a report hands the actual file to the system and clears the cache copy', () async {
    final parent = await Directory.systemTemp.createTemp('harmonia-save-test-');
    final messenger = binding.defaultBinaryMessenger;
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    const documents = MethodChannel('harmonia/avatar_picker');
    messenger.setMockMethodCallHandler(pathProvider, (_) async => parent.path);
    messenger.setMockMethodCallHandler(documents, (call) async {
      expect(call.method, 'saveReport');
      final args = call.arguments as Map;
      expect(args['name'], 'bao-cao.pdf');
      expect(args['mime'], 'application/pdf');
      expect(await File(args['path'] as String).readAsBytes(), [
        37,
        80,
        68,
        70,
      ]);
      return true;
    });
    addTearDown(() async {
      messenger.setMockMethodCallHandler(pathProvider, null);
      messenger.setMockMethodCallHandler(documents, null);
      await parent.delete();
    });

    expect(
      await StaffDocuments.saveReport(
        bytes: [37, 80, 68, 70],
        name: 'bao-cao.pdf',
        mime: 'application/pdf',
        canPresent: () => true,
      ),
      isTrue,
    );
    expect(await parent.list().toList(), isEmpty);
  });
}
