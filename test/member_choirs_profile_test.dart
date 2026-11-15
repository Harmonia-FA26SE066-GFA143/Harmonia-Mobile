import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia_mobile/core/di/core_providers.dart';
import 'package:harmonia_mobile/core/session/session_manager.dart';
import 'package:harmonia_mobile/core/storage/secure_storage_service.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_dto.dart';
import 'package:harmonia_mobile/features/calendar/data/calendar_repository.dart';
import 'package:harmonia_mobile/features/practice/data/practice_repository.dart';
import 'package:harmonia_mobile/features/profile/data/profile_repository.dart';
import 'package:harmonia_mobile/features/profile/presentation/profile_screen.dart';

import 'support/fake_profile_repository.dart';

class _EmptyPracticeHistory extends PracticeSubmissionsNotifier {
  _EmptyPracticeHistory() : super(null);

  @override
  PracticeSubmissionsState build() => const PracticeSubmissionsState();
}

void main() {
  testWidgets('profile displays every choir at narrow width with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FlutterSecureStorage.setMockInitialValues({});
    final session = SessionManager(SecureStorageService());
    await session.markAuthenticated(role: 'ChoirMember');
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          profileRepositoryProvider.overrideWithValue(
            MockProfileRepositoryImpl(
              profile: MockProfileData.profileWithChoirs,
            ),
          ),
          practiceSubmissionsNotifierProvider(null)
              .overrideWith(_EmptyPracticeHistory.new),
          publicAppSettingsProvider.overrideWith(
            (ref) async => const PublicAppSettings(choirName: 'Ca đoàn chung'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ca đoàn'), findsOneWidget);
    expect(find.text(MockProfileData.choirNames.join(' · ')), findsOneWidget);
    expect(find.text('Ca đoàn chung'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
