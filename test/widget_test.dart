import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harmonia_mobile/app/app.dart';

void main() {
  testWidgets('HarmoniaApp boots and displays HomeScreen with tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HarmoniaApp()));
    await tester.pumpAndSettle();

    // Verify main header and greeting
    expect(find.text('Chào Maria Mai'), findsOneWidget);

    // Verify upcoming event card
    expect(find.text('Chúa Nhật XXVI Thường Niên'), findsOneWidget);

    // Verify bottom navigation bar tabs
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Lịch tuần'), findsOneWidget);
    expect(find.text('Luyện tập'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
  });
}
