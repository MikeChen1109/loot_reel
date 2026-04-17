import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loot_reel/loot_reel.dart';

void main() {
  testWidgets('renders the reel and completes a spin', (tester) async {
    final controller = LootReelController();
    String? completedWinner;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: LootReel<String>(
                controller: controller,
                items: const ['USP-S', 'AK-47', 'AWP', 'Sticker'],
                winner: 'Knife',
                spinDuration: const Duration(milliseconds: 80),
                celebrationDuration: const Duration(milliseconds: 80),
                onSpinEnd: (winner) => completedWinner = winner,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LootReel<String>), findsOneWidget);

    controller.spin();
    await tester.pump();

    expect(controller.isSpinning, isTrue);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(controller.isSpinning, isFalse);
    expect(completedWinner, 'Knife');
  });
}
