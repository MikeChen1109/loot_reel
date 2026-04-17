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

  testWidgets('ignores overlapping spin requests', (tester) async {
    final controller = LootReelController();
    var spinStarts = 0;
    var spinEnds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            child: LootReel<String>(
              controller: controller,
              items: const ['USP-S', 'AK-47', 'AWP', 'Sticker'],
              winner: 'Knife',
              spinDuration: const Duration(milliseconds: 80),
              celebrationDuration: const Duration(milliseconds: 80),
              onSpinStart: () => spinStarts++,
              onSpinEnd: (_) => spinEnds++,
            ),
          ),
        ),
      ),
    );

    controller.spin();
    controller.spin();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(spinStarts, 1);
    expect(spinEnds, 1);
  });

  testWidgets('supports weighted item generation', (tester) async {
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
                items: const ['Common', 'Rare', 'Epic'],
                winner: 'Legendary',
                itemWeightBuilder: (item) => switch (item) {
                  'Common' => 10,
                  'Rare' => 3,
                  _ => 1,
                },
                spinDuration: const Duration(milliseconds: 80),
                celebrationDuration: const Duration(milliseconds: 80),
                onSpinEnd: (winner) => completedWinner = winner,
              ),
            ),
          ),
        ),
      ),
    );

    controller.spin();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(completedWinner, 'Legendary');
  });

  test('validates constructor arguments in runtime mode', () {
    expect(
      () => LootReel<String>(items: const [], winner: 'Knife'),
      throwsArgumentError,
    );
    expect(
      () => LootReel<String>(
        items: const ['Knife'],
        winner: 'Knife',
        itemExtent: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => LootReel<String>(
        items: const ['Knife'],
        winner: 'Knife',
        itemSpacing: -1,
      ),
      throwsArgumentError,
    );
    expect(
      () => LootReel<String>(
        items: const ['Knife'],
        winner: 'Knife',
        repeatCount: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => LootReel<String>(
        items: const ['Knife'],
        winner: 'Knife',
        spinDuration: const Duration(milliseconds: -1),
      ),
      throwsArgumentError,
    );
    expect(
      () => LootReel<String>(
        items: const ['Knife'],
        winner: 'Knife',
        celebrationDuration: const Duration(milliseconds: -1),
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          LootReel<String>(items: const ['Knife'], winner: 'Knife', height: 0),
      throwsArgumentError,
    );
  });
}
