import 'package:flutter_test/flutter_test.dart';
import 'package:styleme/app/app.dart';
import 'package:styleme/services/api_service.dart';

void main() {
  setUpAll(() {
    ApiService().init();
  });

  testWidgets('StyleMe smoke test — app arranca sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const StyleMeApp());
    await tester.pump();
    // La app debe renderizar algo (SplashScreen)
    expect(find.byType(StyleMeApp), findsOneWidget);
  });
}
