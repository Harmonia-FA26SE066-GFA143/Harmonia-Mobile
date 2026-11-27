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

void main() {
  testWidgets('profile sections fit a narrow layout with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FlutterSecureStorage.setMockInitialValues({});
    final session = SessionManager(SecureStorageService());
    await session.markAuthenticated(role: 'ChoirMember');
    addTearDown(session.dispose);
    var requestedPracticeRepository = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionManagerProvider.overrideWithValue(session),
          profileRepositoryProvider.overrideWithValue(
            MockProfileRepositoryImpl(
              profile: MockProfileData.profileWithChoirs,
            ),
          ),
          practiceRepositoryProvider.overrideWith((ref) {
            requestedPracticeRepository = true;
            throw StateError('Profile should not load recordings');
          }),
          publicAppSettingsProvider.overrideWith(
            (ref) async => const PublicAppSettings(choirName: 'Ca đoàn chung'),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Ca đoàn'), findsOneWidget);
    expect(find.text(MockProfileData.choirNames.join(' · ')), findsOneWidget);
    expect(find.text('Ca đoàn chung'), findsNothing);

    final declareSkill = find.widgetWithText(TextButton, 'Khai báo');
    final skillsTitle = find.text('Kỹ năng & Thẩm định\nchuyên môn');
    await tester.scrollUntilVisible(declareSkill, 160);
    expect(
      tester.getTopLeft(declareSkill).dy,
      closeTo(tester.getTopLeft(skillsTitle).dy, 1),
    );
    expect(
      tester.getTopLeft(declareSkill).dx,
      greaterThan(tester.getTopRight(skillsTitle).dx),
    );

    await tester.scrollUntilVisible(find.text('Đăng xuất'), 160);
    expect(find.text('Luyện tập gần đây'), findsNothing);
    expect(requestedPracticeRepository, isFalse);
    final settingsTop = tester.getTopLeft(find.text('Cài đặt tài khoản')).dy;
    for (final label in [
      'Đề cử ca trưởng của tôi',
      'Lịch sử tham gia & luyện tập',
    ]) {
      expect(tester.getTopLeft(find.text(label)).dy, greaterThan(settingsTop));
    }
    expect(find.text('Sao chép mã hồ sơ ca viên'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Đăng xuất'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
