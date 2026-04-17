import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:loot_reel/loot_reel.dart';

void main() {
  test('weighted table picks values by cumulative weights', () {
    final table = LootReelDropTable<String>(<LootReelDrop<String>>[
      const LootReelDrop<String>(value: 'common', weight: 1),
      const LootReelDrop<String>(value: 'rare', weight: 3),
    ]);
    final random = _FakeRandom(<double>[0.0, 0.249, 0.26, 0.99]);

    expect(table.pick(random), 'common');
    expect(table.pick(random), 'common');
    expect(table.pick(random), 'rare');
    expect(table.pick(random), 'rare');
  });

  test('weighted table rejects invalid input', () {
    expect(
      () => LootReelDropTable<String>(const <LootReelDrop<String>>[]),
      throwsArgumentError,
    );
    expect(
      () => LootReelDropTable<String>(<LootReelDrop<String>>[
        const LootReelDrop<String>(value: 'broken', weight: -1),
      ]),
      throwsArgumentError,
    );
    expect(
      () => LootReelDropTable<String>(<LootReelDrop<String>>[
        const LootReelDrop<String>(value: 'a', weight: 0),
        const LootReelDrop<String>(value: 'b', weight: 0),
      ]),
      throwsArgumentError,
    );
  });

  test('weighted table supports repeated picks', () {
    final table = LootReelDropTable<String>(<LootReelDrop<String>>[
      const LootReelDrop<String>(value: 'common', weight: 40),
      const LootReelDrop<String>(value: 'legendary', weight: 1),
    ]);

    final results = table.picks(200, math.Random(7));
    final legendaryCount = results
        .where((result) => result == 'legendary')
        .length;

    expect(legendaryCount, lessThan(15));
    expect(results.length, 200);
  });

  test('weighted table rejects negative pick counts', () {
    final table = LootReelDropTable<String>(<LootReelDrop<String>>[
      const LootReelDrop<String>(value: 'common', weight: 1),
    ]);

    expect(() => table.picks(-1), throwsArgumentError);
  });
}

class _FakeRandom implements math.Random {
  _FakeRandom(this.values);

  final List<double> values;
  var _index = 0;

  @override
  bool nextBool() => nextDouble() >= 0.5;

  @override
  double nextDouble() {
    if (_index >= values.length) {
      throw StateError('No more fake random values available.');
    }
    return values[_index++];
  }

  @override
  int nextInt(int max) => (nextDouble() * max).floor();
}
