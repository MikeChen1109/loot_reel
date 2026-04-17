import 'package:flutter_test/flutter_test.dart';
import 'package:loot_reel_example/main.dart';

void main() {
  testWidgets('example app renders loot reel page', (tester) async {
    await tester.pumpWidget(const LootReelExampleApp());

    expect(find.text('Loot Reel'), findsOneWidget);
    expect(find.text('Open case'), findsOneWidget);
  });
}
