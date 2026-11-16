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
  testWidgets('profile displays all choirs and supports editing saint name', (
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
              profile: MemberProfileDto.fromJson({
                ...MockProfileData.profileWithChoirs.toJson(),
                'saintName': 'Giuse',
              }),
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
    expect(find.text('Tên thánh'), findsOneWidget);
    expect(find.text('Giuse'), findsOneWidget);

    final edit = find.text('Chỉnh sửa thông tin cá nhân');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();

    final saintNameField = find.widgetWithText(
      TextField,
      'Tên thánh (không bắt buộc)',
    );
    expect(tester.widget<TextField>(saintNameField).controller?.text, 'Giuse');

    final save = find.text('Lưu thay đổi');
    await tester.enterText(saintNameField, 'a' * 51);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('Tên thánh không được vượt quá 50 ký tự.'),
      findsOneWidget,
    );

    final dobField = find.widgetWithText(TextField, 'dd/mm/yyyy');
    await tester.ensureVisible(dobField);
    await tester.enterText(dobField, '31022004');
    await tester.pumpAndSettle();
    expect(
      find.text('Ngày sinh không hợp lệ (ngày không tồn tại).'),
      findsOneWidget,
    );
    await tester.enterText(dobField, '16052004');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(dobField).controller?.text, '16/05/2004');

    await tester.enterText(saintNameField, '  Têrêsa  ');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Têrêsa'), findsOneWidget);
    expect(find.text('16/05/2004'), findsOneWidget);

    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(saintNameField, '');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Têrêsa'), findsNothing);
    expect(find.text('Chưa cập nhật'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
