import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';
import 'package:harmonia_mobile/features/practice/presentation/practice_list_screen.dart';

import 'support/fake_practice_repository.dart';

void main() {
  testWidgets(
    'a member can filter and open a submitted assignment on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const PracticeListScreen()),
          GoRoute(
            path: '/practice-detail/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Bài tập ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            practiceRepositoryProvider.overrideWithValue(
              MockPracticeRepositoryImpl(),
            ),
            publicAppSettingsProvider.overrideWith(
              (ref) async =>
                  const PublicAppSettings(choirName: 'Ca đoàn kiểm thử'),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passedFilter = find.text('Đã đạt (1)');
      await tester.ensureVisible(passedFilter);
      await tester.pumpAndSettle();
      await tester.tap(passedFilter);
      await tester.pumpAndSettle();

      final openRecording = find.text('Xem bài tập và bản thu');
      await tester.scrollUntilVisible(
        openRecording,
        100,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(openRecording);
      await tester.pumpAndSettle();

      expect(find.text('Bài tập practice-03'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
