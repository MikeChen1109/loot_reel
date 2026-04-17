import 'dart:math' as math;

class LootReelDrop<T> {
  const LootReelDrop({required this.value, this.weight = 1});

  final T value;
  final double weight;
}

class LootReelDropTable<T> {
  LootReelDropTable(Iterable<LootReelDrop<T>> entries)
    : _entries = List<LootReelDrop<T>>.unmodifiable(entries) {
    if (_entries.isEmpty) {
      throw ArgumentError('LootReelDropTable requires at least one entry.');
    }

    for (final entry in _entries) {
      if (!entry.weight.isFinite || entry.weight < 0) {
        throw ArgumentError.value(
          entry.weight,
          'weight',
          'Weights must be finite and greater than or equal to 0.',
        );
      }
    }

    _totalWeight = _entries.fold<double>(0, (sum, entry) => sum + entry.weight);

    if (_totalWeight <= 0) {
      throw ArgumentError(
        'LootReelDropTable requires at least one entry with a positive weight.',
      );
    }
  }

  final List<LootReelDrop<T>> _entries;
  late final double _totalWeight;

  List<LootReelDrop<T>> get entries => _entries;
  double get totalWeight => _totalWeight;

  T pick([math.Random? random]) {
    final rng = random ?? math.Random();
    final target = rng.nextDouble() * _totalWeight;
    var cumulativeWeight = 0.0;

    for (final entry in _entries) {
      cumulativeWeight += entry.weight;
      if (target < cumulativeWeight) {
        return entry.value;
      }
    }

    return _entries.last.value;
  }

  List<T> picks(int count, [math.Random? random]) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Count must be non-negative.');
    }

    final rng = random ?? math.Random();
    return List<T>.generate(count, (_) => pick(rng), growable: false);
  }
}
