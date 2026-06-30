import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aura_agro_ai/data/data_provider.dart';
import 'package:aura_agro_ai/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final provider = DataProvider(loadInitialData: false);

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const AuraAgroApp(),
      ),
    );
    await tester.pump();

    // Verificar que al menos renderice elementos con el texto AURA
    expect(find.text('AURA'), findsWidgets);
  });
}
