import 'package:flutter_test/flutter_test.dart';
import 'package:baggar_conso/main.dart';

void main() {
  testWidgets('Affiche le titre BaggarConso', (WidgetTester tester) async {
    await tester.pumpWidget(BaggarConsoApp()); // حذف const أو أضفها فالكلاس

    // Vérifie que le titre est présent dans l'app bar
    expect(find.text('BaggarConso ⚡'), findsOneWidget); // استعمل النص الكامل
  });
}
