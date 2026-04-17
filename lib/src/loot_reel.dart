import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'weighted_picker.dart';

typedef LootReelItemBuilder<T> =
    Widget Function(BuildContext context, T item, LootReelTileState state);
typedef LootReelItemWeightBuilder<T> = double Function(T item);

enum LootReelTileState { idle, winner, focusedWinner }

class LootReelController {
  _LootReelControllerDelegate? _delegate;

  bool get isSpinning => _delegate?._isSpinning ?? false;

  Future<void> spin() async {
    await _delegate?._spin();
  }
}

abstract class _LootReelControllerDelegate {
  bool get _isSpinning;

  Future<void> _spin();
}

class LootReelSpinCurve extends Curve {
  const LootReelSpinCurve({this.power = 8});

  final double power;

  @override
  double transform(double t) {
    return 1 - math.pow(1 - t, power).toDouble();
  }
}

class LootReel<T> extends StatefulWidget {
  const LootReel({
    super.key,
    required this.items,
    required this.winner,
    this.controller,
    this.itemBuilder,
    this.itemWeightBuilder,
    this.labelBuilder,
    this.onSpinStart,
    this.onSpinEnd,
    this.itemExtent = 112,
    this.itemSpacing = 8,
    this.repeatCount = 40,
    this.spinDuration = const Duration(seconds: 5),
    this.celebrationDuration = const Duration(milliseconds: 1400),
    this.curve = const LootReelSpinCurve(),
    this.indicator,
    this.height = 128,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  }) : assert(items.length > 0),
       assert(itemExtent > 0),
       assert(itemSpacing >= 0),
       assert(repeatCount > 0);

  final List<T> items;
  final T winner;
  final LootReelController? controller;
  final LootReelItemBuilder<T>? itemBuilder;
  final LootReelItemWeightBuilder<T>? itemWeightBuilder;
  final String Function(T item)? labelBuilder;
  final VoidCallback? onSpinStart;
  final ValueChanged<T>? onSpinEnd;
  final double itemExtent;
  final double itemSpacing;
  final int repeatCount;
  final Duration spinDuration;
  final Duration celebrationDuration;
  final Curve curve;
  final Widget? indicator;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  State<LootReel<T>> createState() => _LootReelState<T>();
}

class _LootReelState<T> extends State<LootReel<T>>
    with SingleTickerProviderStateMixin
    implements _LootReelControllerDelegate {
  final ScrollController _scrollController = ScrollController();
  final math.Random _random = math.Random();

  late final AnimationController _celebrationController;

  late List<T> _reelItems;
  late int _winnerIndex;

  bool _finishedSpin = false;
  bool _spinning = false;
  int _celebrationSeed = 0;

  double get _itemStride => widget.itemExtent + widget.itemSpacing;

  @override
  bool get _isSpinning => _spinning;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: widget.celebrationDuration,
    );
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
        oldWidget.repeatCount != widget.repeatCount) {
      _rebuildReel();
    }

    if (oldWidget.celebrationDuration != widget.celebrationDuration) {
      _celebrationController.duration = widget.celebrationDuration;
    }
  }

  @override
  void dispose() {
    _detachController(widget.controller);
    _celebrationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _attachController(LootReelController? controller) {
    if (controller == null) {
      return;
    }
    controller._delegate = this;
  }

  void _detachController(LootReelController? controller) {
    if (controller?._delegate == this) {
      controller!._delegate = null;
    }
  }

  void _rebuildReel() {
    final dropTable = widget.itemWeightBuilder == null
        ? null
        : LootReelDropTable<T>(
            widget.items.map(
              (item) => LootReelDrop<T>(
                value: item,
                weight: widget.itemWeightBuilder!.call(item),
              ),
            ),
          );
    final repeatedItems = dropTable == null
        ? List<T>.generate(
            widget.items.length * widget.repeatCount,
            (index) => widget.items[index % widget.items.length],
            growable: true,
          )
        : dropTable
              .picks(widget.items.length * widget.repeatCount, _random)
              .toList();

    if (dropTable == null) {
      repeatedItems.shuffle(_random);
    }

    _winnerIndex = math.max(0, repeatedItems.length - 6);
    repeatedItems[_winnerIndex] = widget.winner;

    final tailBuffer = dropTable == null
        ? List<T>.generate(
            8,
            (index) => widget.items[index % widget.items.length],
            growable: false,
          )
        : dropTable.picks(8, _random);

    _reelItems = <T>[...repeatedItems, ...tailBuffer];
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
      _celebrationSeed = _random.nextInt(1 << 32);
    });

    _celebrationController.forward(from: 0);
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
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _celebrationController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _CelebrationPainter(
                            progress: _celebrationController.value,
                            seed: _celebrationSeed,
                            colors: <Color>[
                              Colors.amber,
                              Colors.orange,
                              Colors.lightBlueAccent,
                              Colors.white,
                            ],
                          ),
                        );
                      },
                    ),
                  ),
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

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter({
    required this.progress,
    required this.seed,
    required this.colors,
  });

  final double progress;
  final int seed;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }

    final eased = Curves.easeOut.transform(progress);
    final fade = 1 - Curves.easeIn.transform(progress);
    final origin = Offset(size.width / 2, size.height * 0.3);

    for (var index = 0; index < 24; index++) {
      final random = math.Random(seed + (index * 97));
      final angle = random.nextDouble() * math.pi * 2;
      final distance = lerpDouble(24, 132, eased)!;
      final spread = lerpDouble(0, random.nextDouble() * 28, eased)!;
      final gravity = 84 * progress * progress;
      final offset = Offset(
        math.cos(angle) * (distance + spread),
        math.sin(angle) * distance + gravity,
      );
      final radius = lerpDouble(6, 2, progress)!;
      final paint = Paint()
        ..color = colors[index % colors.length].withValues(
          alpha: fade.clamp(0, 1),
        );

      canvas.drawCircle(origin + offset, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.seed != seed;
  }
}
