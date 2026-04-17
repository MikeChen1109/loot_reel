# loot_reel

A reusable Flutter widget for CS-style case opening reels. It gives you a
center-indicated horizontal roll, deterministic winner placement, and a small
celebration burst when the spin ends.

## Features

- Reusable `LootReel<T>` widget instead of a full-screen scaffold
- `LootReelController` to trigger spins from your own UI
- Generic item support with a custom `itemBuilder`
- Built-in default card UI for simple string-based use cases
- Example app included in [`example/`](example)

## Installation

```yaml
dependencies:
  loot_reel: ^0.1.0
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:loot_reel/loot_reel.dart';

final controller = LootReelController();

class Demo extends StatefulWidget {
  const Demo({super.key});

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  static const pool = ['USP-S', 'AK-47', 'AWP', 'Knife', 'Sticker'];
  String winner = 'Knife';

  Future<void> openCase() async {
    setState(() => winner = 'Knife');
    await WidgetsBinding.instance.endOfFrame;
    await controller.spin();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: LootReel<String>(
            controller: controller,
            items: pool,
            winner: winner,
          ),
        ),
        ElevatedButton(
          onPressed: openCase,
          child: const Text('Open case'),
        ),
      ],
    );
  }
}
```

For a complete demo, run the example app:

```bash
cd example
flutter run
```

## Notes

- `winner` is pinned near the end of the reel so the result is guaranteed.
- The reel is intentionally non-scrollable during playback.
- If you need a fully custom look, provide `itemBuilder`.

## License

MIT
