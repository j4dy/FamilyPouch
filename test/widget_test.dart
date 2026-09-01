import 'package:flutter_test/flutter_test.dart';
import 'package:family_pouch/main.dart';

void main() {
  testWidgets('FamilyPouchApp launches and renders main elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FamilyPouchApp());
    await tester.pumpAndSettle();

    expect(find.text('FamilyPouch'), findsOneWidget);
    expect(find.text('Mother'), findsWidgets);
    expect(find.text('Father'), findsWidgets);
    expect(find.text('Helper'), findsWidgets);
  });
}
