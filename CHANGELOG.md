## 0.2.0

- Remove the built-in celebration overlay and `celebrationDuration` API.
- Avoid web rendering issues caused by the internal celebration effect.
- Leave post-spin celebration effects to host apps so packages can add them as needed.

## 0.1.0

- Replace the template package with a reusable loot reel animation widget.
- Add `LootReelController` for externally triggered spins.
- Add weighted reel item generation via `itemWeightBuilder`.
- Add runtime argument validation for safer release builds.
- Refactor reel sequence generation and improve weighted sampling performance.
- Add a complete example app.
- Add widget tests and open-source project metadata.
