import 'dart:math' as math;

/// A weighted entry used by [LootReelDropTable].
class LootReelDrop<T> {
  const LootReelDrop({required this.value, this.weight = 1});

  final T value;
  final double weight;
}

/// Samples values according to their configured weights.
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

    _cumulativeWeights = List<double>.filled(
      _entries.length,
      0,
      growable: false,
    );
    var cumulativeWeight = 0.0;
    for (var index = 0; index < _entries.length; index++) {
      cumulativeWeight += _entries[index].weight;
      _cumulativeWeights[index] = cumulativeWeight;
    }

    _totalWeight = cumulativeWeight;

    if (_totalWeight <= 0) {
      throw ArgumentError(
        'LootReelDropTable requires at least one entry with a positive weight.',
      );
    }
  }

  final List<LootReelDrop<T>> _entries;
  late final List<double> _cumulativeWeights;
  late final double _totalWeight;

  List<LootReelDrop<T>> get entries => _entries;
  double get totalWeight => _totalWeight;

  T pick([math.Random? random]) {
    final rng = random ?? math.Random();
    final target = rng.nextDouble() * _totalWeight;
    return _entries[_findEntryIndex(target)].value;
  }

  List<T> picks(int count, [math.Random? random]) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Count must be non-negative.');
    }

    final rng = random ?? math.Random();
    return List<T>.generate(count, (_) => pick(rng), growable: false);
  }

  int _findEntryIndex(double target) {
    var lowerBound = 0;
    var upperBound = _cumulativeWeights.length - 1;

    while (lowerBound < upperBound) {
      final middle = lowerBound + ((upperBound - lowerBound) >> 1);
      if (target < _cumulativeWeights[middle]) {
        upperBound = middle;
      } else {
        lowerBound = middle + 1;
      }
    }

    return lowerBound;
  }
}
