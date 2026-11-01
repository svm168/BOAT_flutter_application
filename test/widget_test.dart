import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:boat_mobile/core/services/storage_service.dart';
import 'package:boat_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await StorageService().init();
  });

  testWidgets('BOAT App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BoatApp());
    expect(find.byType(BoatApp), findsOneWidget);
  });
}
