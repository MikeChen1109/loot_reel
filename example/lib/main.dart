import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loot_reel/loot_reel.dart';

void main() {
  runApp(const LootReelExampleApp());
}

class LootReelExampleApp extends StatelessWidget {
  const LootReelExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD66A2D),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF120C09),
        useMaterial3: true,
      ),
      home: const _ExamplePage(),
    );
  }
}

enum _OverlayStage { closed, opening, result }

class _ExamplePage extends StatefulWidget {
  const _ExamplePage();

  @override
  State<_ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<_ExamplePage> {
  final LootReelController _controller = LootReelController();
  final math.Random _random = math.Random();

  static const List<_Drop> _drops = <_Drop>[
    _Drop('P250 Sand Dune', 'Common', Color(0xFF7C8A99), weight: 40),
    _Drop('USP-S Cortex', 'Rare', Color(0xFF3B82F6), weight: 24),
    _Drop('AK-47 Neon Rider', 'Epic', Color(0xFFA855F7), weight: 10),
    _Drop('AWP Asiimov', 'Epic', Color(0xFFF97316), weight: 7),
    _Drop('Karambit Fade', 'Legendary', Color(0xFFFACC15), weight: 1.4),
    _Drop('Sport Gloves Vice', 'Legendary', Color(0xFFFB7185), weight: 0.6),
  ];
  late final LootReelDropTable<_Drop> _dropTable = LootReelDropTable<_Drop>(
    _drops.map((drop) => LootReelDrop<_Drop>(value: drop, weight: drop.weight)),
  );

  late _Drop _winner = _drops.last;
  _Drop? _lastOpened;
  _OverlayStage _overlayStage = _OverlayStage.closed;

  bool get _isOpening => _overlayStage == _OverlayStage.opening;
  bool get _showResult => _overlayStage == _OverlayStage.result;

  bool _canAppearInNonWinningSlots(_Drop item, _Drop winner) {
    return !item.isLegendary;
  }

  Future<void> _openCase() async {
    if (_isOpening) {
      return;
    }

    final winner = _dropTable.pick(_random);

    setState(() {
      _winner = winner;
      _overlayStage = _OverlayStage.opening;
    });

    await WidgetsBinding.instance.endOfFrame;
    await _controller.spin();

    if (!mounted) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) {
      return;
    }

    setState(() {
      _lastOpened = winner;
      _overlayStage = _OverlayStage.result;
    });
  }

  void _closeOverlay() {
    if (_isOpening) {
      return;
    }

    setState(() {
      _overlayStage = _OverlayStage.closed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          _MainShowcase(lastOpened: _lastOpened, onOpenCase: _openCase),
          if (_overlayStage != _OverlayStage.closed)
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _showResult
                    ? _ResultOverlay(
                        key: const ValueKey('result_overlay'),
                        winner: _lastOpened!,
                        onDismiss: _closeOverlay,
                        onOpenAgain: _openCase,
                      )
                    : _OpeningOverlay(
                        key: const ValueKey('opening_overlay'),
                        controller: _controller,
                        items: _drops,
                        winner: _winner,
                        itemWeightBuilder: (item) => item.weight,
                        reelItemFilter: _canAppearInNonWinningSlots,
                        itemBuilder: (context, item, state) =>
                            _buildDropTile(context, item, state),
                      ),
              ),
            ),
          Positioned(
            top: 28,
            left: 28,
            child: Text(
              'Loot Reel',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropTile(
    BuildContext context,
    _Drop item,
    LootReelTileState state,
  ) {
    final theme = Theme.of(context);
    final focused = state == LootReelTileState.focusedWinner;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            item.color.withValues(alpha: focused ? 0.95 : 0.72),
            const Color(0xFF181312),
          ],
        ),
        border: Border.all(
          color: focused ? Colors.white : item.color.withValues(alpha: 0.45),
          width: focused ? 2 : 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            blurRadius: focused ? 26 : 14,
            offset: const Offset(0, 12),
            color: item.color.withValues(alpha: focused ? 0.32 : 0.16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.rarity.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 1.2,
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainShowcase extends StatelessWidget {
  const _MainShowcase({required this.lastOpened, required this.onOpenCase});

  final _Drop? lastOpened;
  final VoidCallback onOpenCase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF2B180E),
            Color(0xFF120C09),
            Color(0xFF090807),
          ],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Case Opening Overlay Demo',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Press open case to spawn the reel as an overlay, then swap into a winner panel when the spin ends.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Container(
                          width: 260,
                          height: 320,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                Color(0xFF3D2213),
                                Color(0xFF1A120E),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                blurRadius: 44,
                                offset: const Offset(0, 28),
                                color: Colors.black.withValues(alpha: 0.35),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PRIME CASE',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  letterSpacing: 1.5,
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.inventory_2_rounded,
                                size: 84,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const Spacer(),
                              Text(
                                'Rare finishes, gloves, and knives inside.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white70,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Weighted drops enabled',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: onOpenCase,
                          icon: const Icon(Icons.casino_outlined),
                          label: const Text('Open case'),
                        ),
                        const SizedBox(height: 24),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: lastOpened == null
                              ? Text(
                                  'No drop opened yet',
                                  key: const ValueKey('idle'),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: Colors.white60,
                                  ),
                                )
                              : Text(
                                  'Last drop: ${lastOpened!.name}',
                                  key: ValueKey(lastOpened!.name),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: lastOpened!.color,
                                      ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OpeningOverlay extends StatelessWidget {
  const _OpeningOverlay({
    super.key,
    required this.controller,
    required this.items,
    required this.winner,
    required this.itemWeightBuilder,
    required this.reelItemFilter,
    required this.itemBuilder,
  });

  final LootReelController controller;
  final List<_Drop> items;
  final _Drop winner;
  final LootReelItemWeightBuilder<_Drop> itemWeightBuilder;
  final LootReelItemFilter<_Drop> reelItemFilter;
  final LootReelItemBuilder<_Drop> itemBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF050303).withValues(alpha: 0.88),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Opening case...',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      // horizontal: 18,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: SizedBox(
                      height: 160,
                      child: LootReel<_Drop>(
                        controller: controller,
                        items: items,
                        winner: winner,
                        itemWeightBuilder: itemWeightBuilder,
                        reelItemFilter: reelItemFilter,
                        itemExtent: 160,
                        height: 150,
                        itemBuilder: itemBuilder,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    super.key,
    required this.winner,
    required this.onDismiss,
    required this.onOpenAgain,
  });

  final _Drop winner;
  final VoidCallback onDismiss;
  final VoidCallback onOpenAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onDismiss,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF050303).withValues(alpha: 0.92),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          winner.color.withValues(alpha: 0.38),
                          const Color(0xFF140E0A),
                        ],
                      ),
                      border: Border.all(
                        color: winner.color.withValues(alpha: 0.85),
                        width: 1.4,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          blurRadius: 50,
                          offset: const Offset(0, 24),
                          color: winner.color.withValues(alpha: 0.22),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'You unlocked',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          winner.name,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: winner.color.withValues(alpha: 0.18),
                          ),
                          child: Text(
                            winner.rarity.toUpperCase(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: winner.color,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: onDismiss,
                              child: const Text('Close'),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: onOpenAgain,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Open again'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Drop {
  const _Drop(this.name, this.rarity, this.color, {required this.weight});

  final String name;
  final String rarity;
  final Color color;
  final double weight;

  bool get isLegendary => rarity == 'Legendary';
}
