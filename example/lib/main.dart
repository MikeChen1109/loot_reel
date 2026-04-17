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

class _ExamplePage extends StatefulWidget {
  const _ExamplePage();

  @override
  State<_ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<_ExamplePage> {
  final LootReelController _controller = LootReelController();
  final math.Random _random = math.Random();

  static const List<_Drop> _drops = <_Drop>[
    _Drop('P250 Sand Dune', 'Common', Color(0xFF7C8A99)),
    _Drop('USP-S Cortex', 'Rare', Color(0xFF3B82F6)),
    _Drop('AK-47 Neon Rider', 'Epic', Color(0xFFA855F7)),
    _Drop('AWP Asiimov', 'Epic', Color(0xFFF97316)),
    _Drop('Karambit Fade', 'Legendary', Color(0xFFFACC15)),
    _Drop('Sport Gloves Vice', 'Legendary', Color(0xFFFB7185)),
  ];

  late _Drop _winner = _drops.last;
  _Drop? _lastOpened;
  bool _opening = false;

  Future<void> _openCase() async {
    if (_opening || _controller.isSpinning) {
      return;
    }

    setState(() {
      _opening = true;
      _winner = _drops[_random.nextInt(_drops.length)];
      _lastOpened = null;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;
      await _controller.spin();
    } finally {
      if (mounted) {
        setState(() {
          _opening = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Loot Reel',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Reusable Flutter case-opening animation package',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 150,
                child: LootReel<_Drop>(
                  controller: _controller,
                  items: _drops,
                  winner: _winner,
                  itemExtent: 160,
                  height: 140,
                  onSpinEnd: (winner) {
                    setState(() {
                      _lastOpened = winner;
                    });
                  },
                  itemBuilder: (context, item, state) {
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
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
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
                  },
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _opening ? null : _openCase,
                icon: const Icon(Icons.casino_outlined),
                label: Text(_opening ? 'Rolling...' : 'Open case'),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _lastOpened == null
                    ? Text(
                        'Press the button to spin',
                        key: const ValueKey('idle'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white60,
                        ),
                      )
                    : Text(
                        'Winner: ${_lastOpened!.name}',
                        key: ValueKey(_lastOpened!.name),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _lastOpened!.color,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Drop {
  const _Drop(this.name, this.rarity, this.color);

  final String name;
  final String rarity;
  final Color color;
}
