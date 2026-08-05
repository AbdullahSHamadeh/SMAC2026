import 'package:flutter_test/flutter_test.dart';
import 'package:family_compass/main.dart';

void main() {
  testWidgets('shows the Family Compass dashboard', (tester) async {
    await tester.pumpWidget(const FamilyCompassApp());
    expect(find.text('Family Compass'), findsOneWidget);
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('Dad'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Family dinner'), 300);
    expect(find.text('Family dinner'), findsOneWidget);
  });
}
