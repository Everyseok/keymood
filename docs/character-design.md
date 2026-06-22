# KeyMood Character Design

KeyMood's first character direction is a tiny white submarine-like engine companion for the macOS menu bar.

The character should feel alive like a menu bar companion, but it should express typing force through engine behavior instead of literal emotion analysis.

## Asset Contract

- Transparent background.
- Mostly white silhouette parts.
- Red eye-flame accents are allowed from `half_ahead` upward.
- No grayscale fills, shadows, or decorative outlines.
- Simple rounded SVG parts that stay readable at 16-22 px menu bar size.
- Mood changes should come from propeller speed, body motion, smoke density, wake marks, and eye shape.

## Parts

| Part | Purpose |
|---|---|
| `body` | Main submarine silhouette |
| `eye_left`, `eye_right` | Transparent cutout eyes inside the body |
| `chimney` | Smoke source and engine cue |
| `smoke_puffs` | Typing-force intensity cue |
| `propeller` | Primary motion cue |
| `wake_marks` | Secondary intensity cue |
| `underside_fin` | Keeps the silhouette submarine-like |

## Regimes

| Regime | UI label | Visual behavior |
|---|---|---|
| `dead_slow` | Dead Slow | Barely moving, slow propeller, soft round eyes, almost no smoke |
| `slow_ahead` | Slow Ahead | Smooth cruising, steady propeller, small regular smoke, tiny wake |
| `half_ahead` | Half Ahead | Snappier bounce, faster propeller, more smoke, playful wake, small red eye flames |
| `full_ahead` | Full Ahead | Maximum output, larger red eye flames, very fast propeller, densest smoke and wake |
| `standby` | Standby | Cooling down, soft motion, slower propeller, long exhale-like smoke |

## Files

| File | Use |
|---|---|
| `docs/assets/character/dead_slow.svg` | Transparent animated SVG for Dead Slow |
| `docs/assets/character/slow_ahead.svg` | Transparent animated SVG for Slow Ahead |
| `docs/assets/character/half_ahead.svg` | Transparent animated SVG for Half Ahead |
| `docs/assets/character/full_ahead.svg` | Transparent animated SVG for Full Ahead |
| `docs/assets/character/standby.svg` | Transparent animated SVG for Standby |
| `docs/assets/character/preview.svg` | Dark-background review sheet for comparing states |

## Implementation Note

The macOS menu bar app currently uses an AppKit vector renderer inspired by these SVGs. The SVG files remain the design reference and documentation assets; the status item draws lightweight frames at runtime so propeller motion, bobbing, smoke, wake, flame eyes, and sparks remain visible even when SVG CSS animation is unavailable in `NSImage`.
