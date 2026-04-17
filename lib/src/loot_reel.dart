import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'weighted_picker.dart';

/// Builds a tile for each reel item.
typedef LootReelItemBuilder<T> =
    Widget Function(BuildContext context, T item, LootReelTileState state);

/// Returns the relative frequency for an item when generating the reel.
typedef LootReelItemWeightBuilder<T> = double Function(T item);

/// Returns whether an item is allowed to appear in non-winning reel slots.
typedef LootReelItemFilter<T> = bool Function(T item, T winner);

const int _winnerOffsetFromTail = 6;
const int _tailBufferLength = 8;

List<T> _validatedItems<T>(List<T> items) {
  if (items.isEmpty) {
    throw ArgumentError.value(
      items,
      'items',
      'LootReel requires at least one item.',
    );
  }

  return List<T>.unmodifiable(items);
}

double _validatedPositiveDouble(String name, double value) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(
      value,
      name,
      '$name must be finite and greater than 0.',
    );
  }

  return value;
}

double _validatedNonNegativeDouble(String name, double value) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(
      value,
      name,
      '$name must be finite and greater than or equal to 0.',
    );
  }

  return value;
}

int _validatedPositiveInt(String name, int value) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, '$name must be greater than 0.');
  }

  return value;
}

Duration _validatedNonNegativeDuration(String name, Duration value) {
  if (value < Duration.zero) {
    throw ArgumentError.value(
      value,
      name,
      '$name must be greater than or equal to zero.',
    );
  }

  return value;
}

/// The visual state of a reel tile during playback.
enum LootReelTileState { idle, winner, focusedWinner }

/// Controls a [LootReel] from outside the widget tree.
class LootReelController {
  _LootReelControllerDelegate? _delegate;

  /// Whether the attached reel is currently spinning.
  bool get isSpinning => _delegate?._isSpinning ?? false;

  /// Starts a spin on the attached reel.
  ///
  /// If no reel is attached, this completes immediately.
  Future<void> spin() async {
    await _delegate?._spin();
  }
}

abstract class _LootReelControllerDelegate {
  bool get _isSpinning;

  Future<void> _spin();
}

/// A decelerating curve tuned for slot-style reel motion.
class LootReelSpinCurve extends Curve {
  const LootReelSpinCurve({this.power = 8});

  final double power;

  @override
  double transform(double t) {
    return 1 - math.pow(1 - t, power).toDouble();
  }
}

/// A horizontally scrolling loot reel with deterministic winner placement.
class LootReel<T> extends StatefulWidget {
  LootReel({
    super.key,
    required List<T> items,
    required this.winner,
    this.controller,
    this.itemBuilder,
    this.itemWeightBuilder,
    this.reelItemFilter,
    this.labelBuilder,
    this.onSpinStart,
    this.onSpinEnd,
    double itemExtent = 112,
    double itemSpacing = 8,
    int repeatCount = 40,
    Duration spinDuration = const Duration(seconds: 5),
    this.curve = const LootReelSpinCurve(),
    this.indicator,
    double height = 128,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  }) : items = _validatedItems(items),
       itemExtent = _validatedPositiveDouble('itemExtent', itemExtent),
       itemSpacing = _validatedNonNegativeDouble('itemSpacing', itemSpacing),
       repeatCount = _validatedPositiveInt('repeatCount', repeatCount),
       spinDuration = _validatedNonNegativeDuration(
         'spinDuration',
         spinDuration,
       ),
       height = _validatedPositiveDouble('height', height);

  final List<T> items;
  final T winner;
  final LootReelController? controller;
  final LootReelItemBuilder<T>? itemBuilder;
  final LootReelItemWeightBuilder<T>? itemWeightBuilder;

  /// Filters which source items may appear in non-winning reel slots.
  ///
  /// The [winner] is always injected into the final winning slot even if this
  /// filter returns `false` for it.
  final LootReelItemFilter<T>? reelItemFilter;
  final String Function(T item)? labelBuilder;
  final VoidCallback? onSpinStart;
  final ValueChanged<T>? onSpinEnd;
  final double itemExtent;
  final double itemSpacing;
  final int repeatCount;
  final Duration spinDuration;
  final Curve curve;
  final Widget? indicator;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  State<LootReel<T>> createState() => _LootReelState<T>();
}

class _LootReelState<T> extends State<LootReel<T>>
    implements _LootReelControllerDelegate {
  final ScrollController _scrollController = ScrollController();
  final math.Random _random = math.Random();

  late List<T> _reelItems;
  late int _winnerIndex;

  bool _finishedSpin = false;
  bool _spinning = false;

  double get _itemStride => widget.itemExtent + widget.itemSpacing;

  @override
  bool get _isSpinning => _spinning;

  @override
  void initState() {
    super.initState();
    _rebuildReel();
    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant LootReel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      _attachController(widget.controller);
    }

    if (!listEquals(oldWidget.items, widget.items) ||
        oldWidget.winner != widget.winner ||
        oldWidget.repeatCount != widget.repeatCount ||
        oldWidget.itemWeightBuilder != widget.itemWeightBuilder ||
        oldWidget.reelItemFilter != widget.reelItemFilter) {
      _rebuildReel();
    }
  }

  @override
  void dispose() {
    _detachController(widget.controller);
    _scrollController.dispose();
    super.dispose();
  }

  void _attachController(LootReelController? controller) {
    if (controller == null) {
      return;
    }
    if (controller._delegate != null && controller._delegate != this) {
      throw StateError(
        'A LootReelController can only be attached to one LootReel at a time.',
      );
    }
    assert(
      controller._delegate == null || controller._delegate == this,
      'A LootReelController can only be attached to one LootReel at a time.',
    );
    controller._delegate = this;
  }

  void _detachController(LootReelController? controller) {
    if (controller?._delegate == this) {
      controller!._delegate = null;
    }
  }

  void _rebuildReel() {
    final eligibleItems = _buildEligibleItems();
    final dropTable = _buildDropTable(eligibleItems);
    final repeatedItems = _buildRepeatedItems(eligibleItems, dropTable);

    _winnerIndex = _resolveWinnerIndex(repeatedItems.length);
    repeatedItems[_winnerIndex] = widget.winner;

    _reelItems = <T>[
      ...repeatedItems,
      ..._buildTailBuffer(eligibleItems, dropTable),
    ];
  }

  List<T> _buildEligibleItems() {
    final reelItemFilter = widget.reelItemFilter;
    if (reelItemFilter == null) {
      return widget.items;
    }

    final eligibleItems = widget.items
        .where((item) => reelItemFilter(item, widget.winner))
        .toList(growable: false);

    if (eligibleItems.isEmpty) {
      throw ArgumentError(
        'LootReel requires at least one eligible item after applying '
        'reelItemFilter.',
      );
    }

    return eligibleItems;
  }

  LootReelDropTable<T>? _buildDropTable(List<T> eligibleItems) {
    final itemWeightBuilder = widget.itemWeightBuilder;
    if (itemWeightBuilder == null) {
      return null;
    }

    return LootReelDropTable<T>(
      eligibleItems.map(
        (item) => LootReelDrop<T>(value: item, weight: itemWeightBuilder(item)),
      ),
    );
  }

  List<T> _buildRepeatedItems(
    List<T> eligibleItems,
    LootReelDropTable<T>? dropTable,
  ) {
    final itemCount = eligibleItems.length * widget.repeatCount;
    if (dropTable != null) {
      return dropTable.picks(itemCount, _random).toList(growable: true);
    }

    final items = List<T>.generate(
      itemCount,
      (index) => eligibleItems[index % eligibleItems.length],
      growable: true,
    );
    items.shuffle(_random);
    return items;
  }

  List<T> _buildTailBuffer(
    List<T> eligibleItems,
    LootReelDropTable<T>? dropTable,
  ) {
    if (dropTable != null) {
      return dropTable.picks(_tailBufferLength, _random);
    }

    return List<T>.generate(
      _tailBufferLength,
      (index) => eligibleItems[index % eligibleItems.length],
      growable: false,
    );
  }

  int _resolveWinnerIndex(int repeatedItemCount) {
    return math.max(0, repeatedItemCount - _winnerOffsetFromTail);
  }

  @override
  Future<void> _spin() async {
    if (_spinning) {
      return;
    }

    setState(() {
      _spinning = true;
      _finishedSpin = false;
      _rebuildReel();
    });

    widget.onSpinStart?.call();

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scrollController.hasClients) {
      if (mounted) {
        setState(() {
          _spinning = false;
        });
      } else {
        _spinning = false;
      }
      return;
    }

    _scrollController.jumpTo(0);

    final maxJitter = math.max(0.0, widget.itemExtent / 2 - 10);
    final jitter = (_random.nextDouble() * maxJitter * 2) - maxJitter;
    final targetOffset = ((_winnerIndex * _itemStride) + jitter).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    await _scrollController.animateTo(
      targetOffset,
      duration: widget.spinDuration,
      curve: widget.curve,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _spinning = false;
      _finishedSpin = true;
    });

    widget.onSpinEnd?.call(widget.winner);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final sidePadding = math
            .max((viewportWidth - widget.itemExtent) / 2, 0)
            .toDouble();

        return SizedBox(
          height: widget.height,
          child: Padding(
            padding: widget.padding,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ListView.separated(
                  controller: _scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  itemCount: _reelItems.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: widget.itemSpacing),
                  itemBuilder: (context, index) {
                    final state = switch (index == _winnerIndex) {
                      false => LootReelTileState.idle,
                      true when _finishedSpin =>
                        LootReelTileState.focusedWinner,
                      _ => LootReelTileState.winner,
                    };

                    return SizedBox(
                      width: widget.itemExtent,
                      child: _buildItem(context, _reelItems[index], state),
                    );
                  },
                ),
                IgnorePointer(
                  child: widget.indicator ?? const _DefaultIndicator(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, T item, LootReelTileState state) {
    return widget.itemBuilder?.call(context, item, state) ??
        _DefaultLootTile(
          label: widget.labelBuilder?.call(item) ?? item.toString(),
          state: state,
        );
  }
}

class _DefaultLootTile extends StatelessWidget {
  const _DefaultLootTile({required this.label, required this.state});

  final String label;
  final LootReelTileState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWinner = state != LootReelTileState.idle;
    final isFocused = state == LootReelTileState.focusedWinner;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            isFocused ? const Color(0xFFF7B733) : theme.colorScheme.surface,
            isFocused
                ? const Color(0xFFFC4A1A)
                : theme.colorScheme.surfaceContainerHighest,
          ],
        ),
        border: Border.all(
          color: isWinner
              ? Colors.amberAccent
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: isFocused ? 2 : 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: isFocused ? 24 : 10,
            offset: const Offset(0, 10),
            color: (isFocused ? Colors.orange : Colors.black).withValues(
              alpha: 0.16,
            ),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: isFocused ? Colors.white : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _DefaultIndicator extends StatelessWidget {
  const _DefaultIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: Colors.amberAccent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    blurRadius: 18,
                    color: Colors.amber.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
