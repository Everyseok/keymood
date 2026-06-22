# KeyMood UX/UI Spec

## 1. Design Goal

KeyMood is a macOS menu bar companion that reacts to physical typing force, not typed content.

The design should feel like a native Mac utility: quiet, compact, glanceable, and always available from the menu bar. It should not feel like a web dashboard or a marketing app.

Primary design objective:

```text
MacBook typing force -> stable mood state -> small expressive menu bar companion
```

The current implementation is already testable:

```bash
swift run keymood-menubar
```

Working Figma file:

```text
https://www.figma.com/design/KchMctn55EfQ9Q4XPanxa2
```

Current menu bar status item:

```text
Animated character icon only
```

The native menu opened from the icon shows a read-only regime rail that highlights the current intensity stage, character selection, the current regime, sensitivity slider, Roaming Mode switch, pause/resume, and quit actions.

## 2. UX Principles

- **Menu bar first**: the product lives in the macOS menu bar, not in a large primary window.
- **Glanceable state**: the user should understand current mood in under one second.
- **No content analysis**: never imply that KeyMood reads typed text, key names, prompts, or app content.
- **Dead Slow by default**: idle/normal typing should not feel judged or noisy.
- **Physical, not psychological**: labels should represent physical typing energy translated into mood-like expression.
- **Native macOS feel**: use compact spacing, SF Symbols-style iconography, native menu/popover patterns, and restrained controls.
- **Slow recovery**: `Full Ahead` states should relax gradually into `Standby` instead of snapping back.

## 3. Product Surfaces

### A. Menu Bar Item

The always-visible surface is a tiny animated character. The default character is Submarine; Cheer Frog is available from the Character submenu as an original monochrome arms-up cheering companion.

States:

| RuntimeMood | Menu label | Character direction |
|---|---|---|
| `calm` | `Dead Slow` | lowest active engine, neutral movement |
| `focused` | `Slow Ahead` | steady low-forward motion |
| `charged` | `Half Ahead` | energized mid-power motion with red eye flame |
| `intense` | `Full Ahead` | sustained high-power expression with larger flame, smoke, wake, and sparks |
| `relaxing` | `Standby` | cooling down, slow reset |
| paused | `Paused` | dimmed/sleeping |
| no sensor | `No Sensor` | inactive/error-safe |

Design notes:

- The menu bar item must stay visually small.
- The status item should show only the selected character icon; state labels belong inside the native menu.
- Roaming Mode is optional and off by default; when enabled, the status item becomes a wider transparent track and the selected character travels edge-to-edge before reversing.
- Avoid large, colorful, distracting menu bar art.
- Character motion should be subtle in normal use.

### B. Menu Popover / Menu

Current implementation uses an `NSMenu`. Figma should model it as a compact menu-popover panel even if the implementation remains `NSMenu` for MVP.

Required content:

```text
Read-only regime rail
Current mood
sensitivity slider
Roaming Mode
Pause / Resume
Quit
```

Recommended visual hierarchy:

1. Mood summary
2. Sensitivity control
3. Controls

### C. Calibration Flow

Not implemented yet, but should be designed now because it affects app trust.

Flow:

```text
Ready
Soft typing
Normal typing
Firm typing
Threshold preview
Save profile
```

Important copy:

- Say that typed content is not read or saved.
- Ask the user to type in any text field, not necessarily inside KeyMood.
- Show only aggregate signal values.

### D. Sensor Unavailable State

Required because AppleSPU raw sensor is hardware and macOS dependent.

States:

```text
No Sensor
Sensor Open: waiting for reports
Permission or access failed
Paused
```

This state should be calm and explanatory, not scary.

## 4. Figma File Structure

Create a Figma file named:

```text
KeyMood macOS UX
```

Recommended pages:

```text
00 Cover
01 Menu Bar MVP
02 Popover States
03 Calibration Flow
04 Character States
05 Components
06 Handoff
```

### 00 Cover

Include:

- Product name: KeyMood
- One-line description:

```text
MacBook typing-force mood companion for the macOS menu bar.
```

- Privacy line:

```text
Reads motion signal, not typed content.
```

### 01 Menu Bar MVP

Frames:

- `Menu Bar - Dead Slow`
- `Menu Bar - Slow Ahead`
- `Menu Bar - Half Ahead`
- `Menu Bar - Full Ahead`
- `Menu Bar - Standby`
- `Menu Bar - Paused`
- `Menu Bar - No Sensor`

Each frame should show:

- macOS top menu bar crop
- KeyMood item on the right side
- current character state

### 02 Popover States

Frames:

- `Popover - Dead Slow`
- `Popover - Slow Ahead`
- `Popover - Half Ahead`
- `Popover - Full Ahead`
- `Popover - Standby`
- `Popover - Paused`
- `Popover - No Sensor`

Each popover should include:

- Current mood row
- Sensitivity slider
- Pause/Resume button
- Quit row

### 03 Calibration Flow

Frames:

- `Calibration - Intro`
- `Calibration - Soft Typing`
- `Calibration - Normal Typing`
- `Calibration - Firm Typing`
- `Calibration - Threshold Preview`
- `Calibration - Saved`

Design goals:

- Keep it simple and trust-building.
- Show progress.
- Show that only sensor energy is measured.
- Do not ask users to type private content.

### 04 Character States

Frames:

- `Character - Dead Slow`
- `Character - Slow Ahead`
- `Character - Half Ahead`
- `Character - Full Ahead`
- `Character - Standby`
- `Character - Paused`
- `Character - No Sensor`

Character direction:

- Original tiny white submarine-like engine companion, not a RunCat/SlapMac copy.
- Use transparent-background SVG silhouette assets: white body parts, with red eye-flame accents for `Half Ahead` and `Full Ahead`.
- Small silhouette should read at menu bar size.
- Each mood should be readable even at tiny size.
- Movement intensity should map to `poseEnergy`.
- Regime differences should come from propeller speed, body bounce, smoke puffs, wake marks, and eye shape.

### 05 Components

Components:

- `MoodBadge`
- `SensitivitySlider`
- `MenuActionRow`
- `CharacterGlyph`
- `CalibrationStepCard`

### 06 Handoff

Include implementation mapping:

| Design concept | Current code source |
|---|---|
| Mood display | `RuntimeMood.label` |
| Internal mood logic | `RuntimeMood` |
| Signal intensity | `RawMotionSnapshot.smoothedEnergy` |
| Impact | `RawMotionSnapshot.lastImpact` |
| Character intensity | `MoodStateMachine.poseEnergy` |
| Sensitivity | `KeyMoodMenuBar.sensitivity` |
| Sensor status | `AppleSPUSensorReader.hasDevices` + diagnostics |

## 5. Popover Information Architecture

Recommended MVP popover layout:

```text
┌──────────────────────────────┐
│ Character / Mood summary      │
│ Dead Slow, Slow Ahead...      │
├──────────────────────────────┤
│ Sensitivity   [-----●---] 30  │
├──────────────────────────────┤
│ Pause / Resume                │
│ Calibrate...                  │
│ Quit KeyMood                  │
└──────────────────────────────┘
```

Current implementation does not yet include `Calibrate...` in the menu bar app, but the design should reserve space for it.

## 6. Mood Copy

Use concise labels:

| Internal mood | Display label | Description |
|---|---|---|
| calm | Dead Slow | lowest active typing-force regime |
| focused | Slow Ahead | steady low-forward typing force |
| charged | Half Ahead | short mid/high-impact bursts |
| intense | Full Ahead | sustained high-impact typing |
| relaxing | Standby | cooling down after high intensity |
| paused | Paused | sensor stopped by user |
| no sensor | No Sensor | supported sensor unavailable |

Avoid copy like:

- "angry"
- "stressed"
- "sad"
- "we know how you feel"
- "AI detected your emotion"

Reason:

KeyMood interprets physical typing dynamics, not actual psychological emotion.

## 7. Visual Direction

Preferred:

- native macOS utility feel
- compact surface
- soft but not childish
- readable meters
- tiny character with stateful motion
- dark/light mode ready

Avoid:

- large dashboard
- web SaaS card-heavy UI
- marketing hero layout
- loud gradients
- overly literal anger/stress visuals
- copied RunCat or SlapMac character style

## 8. Figma Execution Notes

If using Apple Design Resources:

- Use macOS menu/popover proportions as reference.
- Use official macOS spacing and control proportions where possible.
- Do not redistribute Apple resource components as a standalone product.
- Use the resource as platform guidance for a macOS app.

If starting from a blank Figma file:

- Build a lightweight macOS-like component set.
- Use SF Symbols-style icon placeholders.
- Keep frames compact and implementation-oriented.
- Name layers for developer handoff.

## 9. Design Acceptance Checklist

- [ ] Menu bar states are all represented.
- [ ] Popover has Dead Slow/Slow Ahead/Half Ahead/Full Ahead/Standby/paused/no-sensor variants.
- [ ] Calibration flow explains privacy clearly.
- [ ] Character states are visually distinct at menu bar size.
- [ ] Design maps directly to current code values.
- [ ] No screen implies typed content is read.
- [ ] Sensitivity control matches current 0-100 slider.
- [ ] Sensor unavailable state is present.
- [ ] Pause/Resume and Quit are easy to find.
- [ ] Figma handoff includes implementation mapping.

## 10. Next Step

After this spec is approved:

1. Open or duplicate the Apple macOS Design Resources Figma file.
2. Create a `KeyMood MVP` page.
3. Build frames from this spec.
4. Review with the running `swift run keymood-menubar` MVP side by side.
5. After approval, implement the selected UI details in the macOS app.
