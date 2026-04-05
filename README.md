# HappyPlants

A Flutter plant care tracker with animated SVG illustrations. Keep your plants happy by logging waterings and fertilizing, and watch them sway when they're well taken care of.

<br>

<p align="center">
  <img src="assets/images/plants/preview.png" alt="HappyPlants cactus" width="180">
</p>

<br>

## Features

- **Plant library** — add as many plants as you want, each with a name, species, watering schedule, and illustration
- **Care logging** — one-tap logging for watering and fertilizing; timestamps stored locally
- **Overdue indicators** — plant cards show days until next watering or a red "Overdue!" badge when a plant needs attention
- **Animated illustrations** — 7 hand-crafted SVG plants sway gently when happy; droop slowly when care is overdue
- **Plant picker** — a scrollable 3-column grid previewing all illustrations; selected plant animates live, others stay still
- **Fully offline** — all data stored on-device with SQLite; no account or network required

## Tech Stack

| Concern | Solution |
|---------|----------|
| Framework | Flutter 3 / Dart |
| State management | `setState` (no external package) |
| Local storage | SQLite via [`sqflite`](https://pub.dev/packages/sqflite) |
| SVG rendering | [`flutter_svg`](https://pub.dev/packages/flutter_svg) |
| Date formatting | [`intl`](https://pub.dev/packages/intl) |
| Test DB (in-memory) | [`sqflite_common_ffi`](https://pub.dev/packages/sqflite_common_ffi) |

## Project Structure

```
lib/
├── models/
│   ├── plant.dart               # Plant data class — copyWith, toMap/fromMap,
│   │                            #   nextWateringDate, isOverdueForWater
│   ├── care_log.dart            # CareLog + CareType enum (watering/fertilizing)
│   ├── plant_definition.dart    # PlantDefinition + PlantPart: SVG layout &
│   │                            #   animation parameters for each illustration
│   └── plant_images.dart        # Key/label list used by the plant picker
│
├── repositories/
│   ├── plant_repository.dart    # CRUD for the plants table
│   └── care_log_repository.dart # CRUD for the care_logs table
│
├── screens/
│   ├── home_screen.dart         # Plant list with overdue highlighting
│   ├── add_plant_screen.dart    # Form: name, species, interval, illustration
│   └── plant_detail_screen.dart # Care history, log watering/fertilizing, edit/delete
│
├── widgets/
│   ├── plant_widget.dart        # Animated SVG plant (or drawn fallback)
│   ├── plant_card.dart          # Home list tile
│   └── plant_picker.dart        # Illustration selector grid
│
└── theme/
    └── app_theme.dart           # Color palette + TextTheme

assets/
└── images/plants/
    ├── plant_01/   # Vine          (3 SVG parts)
    ├── plant_02/   # Snake Plant   (8 SVG parts)
    ├── plant_03/   # Cactus        (2 SVG parts)
    ├── plant_05/   # Pancake Plant (5 SVG parts)
    ├── plant_07/   # Trailing      (2 SVG parts)
    ├── plant_14/   # Monstera      (4 SVG parts)
    └── plant_15/   # Tea Plant     (1 SVG part)
```

## Animation System

Each plant illustration is described by a `PlantDefinition` — a canvas size and a list of `PlantPart` entries. Every part carries:

| Field | Purpose |
|-------|---------|
| `asset` | Path to the SVG file |
| `left` / `bottom` | Position on the canvas (bottom-left origin) |
| `width` / `height` | Rendered size |
| `happyAmplitude` | Peak rotation in radians when happy; ×0.3 when sad |
| `phaseOffset` | `0.0–1.0` stagger so leaves don't move in sync |
| `baseAngle` | Constant rotation offset applied before sway (used to permanently tilt individual stems) |
| `swayAlignment` | Pivot point — `BottomCenter` (default), `BottomLeft`, or `BottomRight` |

Sway formula applied each frame:

```
angle = baseAngle + sin(controller.value × 2π + phaseOffset × 2π) × amplitude
```

- Happy plants: 4 s cycle, full amplitude
- Sad plants: 8 s cycle, amplitude × 0.3
- `isStatic: true`: renders at `baseAngle` only, no animation (used in the picker for unselected tiles)

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.0
- Android SDK or Xcode (for device/emulator)

### Run

```bash
git clone https://github.com/ethancs13/HappyPlants-app.git
cd HappyPlants-app
flutter pub get
flutter run
```

### Test

```bash
flutter test          # all unit + widget tests
flutter analyze       # static analysis
```

### Build

```bash
# Android APK
flutter build apk

# Android App Bundle (Play Store)
flutter build appbundle

# iOS
flutter build ios
```

## Database Schema

### `plants`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `INTEGER PRIMARY KEY AUTOINCREMENT` | |
| `name` | `TEXT NOT NULL` | |
| `species` | `TEXT NOT NULL` | |
| `watering_interval_days` | `INTEGER NOT NULL` | |
| `last_watered_date` | `TEXT` | ISO 8601 |
| `last_fertilized_date` | `TEXT` | ISO 8601 |
| `notes` | `TEXT` | optional |
| `plant_key` | `TEXT` | illustration key, e.g. `plant_02` |

### `care_logs`

| Column | Type | Notes |
|--------|------|-------|
| `id` | `INTEGER PRIMARY KEY AUTOINCREMENT` | |
| `plant_id` | `INTEGER NOT NULL` | FK → `plants.id` |
| `type` | `TEXT NOT NULL` | `'watering'` or `'fertilizing'` |
| `date` | `TEXT` | ISO 8601 |
| `notes` | `TEXT` | optional |

## License

MIT License

Copyright (c) 2026 ethancs13

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
