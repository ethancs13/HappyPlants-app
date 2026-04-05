# HappyPlants

A Flutter plant care tracker with animated SVG illustrations. Keep your plants happy by logging waterings and fertilizing, and watch them sway when they're well taken care of.

<br>

<p align="center">
  <svg width="120" height="105" viewBox="0 0 120 105" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M16.5044 90.9955C5.02088 77.8173 0.594413 16.4412 16.5044 16.4412C43.0632 16.4412 80.2709 20.4123 103.643 16.4412C119.236 13.7853 115.025 77.7035 103.643 90.9955C88.3776 108.828 31.9085 108.676 16.5044 90.9955Z" fill="#A0624D"/>
    <path d="M0 19.6662V7.91703C0 3.54115 3.54119 0 7.91707 0H112.078C116.454 0 119.995 3.54115 119.995 7.91703V19.6662C119.995 24.042 116.454 27.5832 112.078 27.5832H7.91707C3.54119 27.5832 0 24.0294 0 19.6662Z" fill="#D08B40"/>
  </svg>
</p>

<p align="center">
  <svg width="80" height="140" viewBox="0 0 192 310" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M32.4847 309.94C15.6824 245.98 -1.22055 179.225 12.2187 114.485C16.35 94.5713 23.7057 74.6454 37.7747 59.9718C51.8438 45.2856 73.7345 36.8718 93.1314 42.9554C109.782 48.1825 122.05 63.108 128.033 79.5072C134.016 95.9064 134.558 113.741 134.155 131.199C132.756 191.669 120.728 251.875 98.7741 308.239C75.8757 305.846 52.5365 307.761 32.4847 309.94Z" fill="#98A763"/>
    <path d="M120.992 147.648C122.441 152.863 126.547 157.258 131.661 159.047C136.762 160.836 142.732 159.979 147.115 156.818C153.186 152.447 155.604 144.739 159.131 138.139C162.645 131.539 169.207 125.039 176.525 126.589C181.437 127.634 185.027 132.231 186.136 137.131C187.244 142.031 186.299 147.17 184.889 151.981C181.715 162.788 176.147 172.877 168.691 181.316C164.522 186.039 159.685 190.321 153.942 192.916C148.198 195.511 141.46 196.317 135.552 194.138C126.396 190.762 120.917 180.9 119.871 171.202C118.826 161.503 121.383 151.817 120.992 147.648Z" fill="#98A763"/>
    <path d="M75.1073 48.0565C68.268 44.2527 63.3054 37.2497 61.9829 29.5413C61.5169 26.8459 61.4917 23.9994 62.5497 21.4803C63.6077 18.9612 65.9001 16.8452 68.6207 16.5807C73.7596 16.0769 77.1477 21.6566 79.2134 26.3925C77.5886 18.6463 79.2134 10.283 83.6092 3.69561C84.9443 1.70554 86.9721 -0.322304 89.3401 0.0429621C91.9473 0.446014 93.2068 3.41852 93.7736 6.00057C95.2221 12.6761 95.1213 19.6666 93.5091 26.3043C92.6652 22.9162 95.0206 19.0998 98.3961 18.2559C101.772 17.3994 105.613 19.5406 106.747 22.8406C107.893 26.1406 106.281 30.1207 103.233 31.8085C103.585 28.6219 107.603 26.72 110.588 27.9165C113.574 29.1131 115.224 32.5516 115.06 35.7509C114.896 38.9627 113.233 41.91 111.168 44.3787C106.911 49.4924 100.714 53.0065 94.1137 53.7874C87.4886 54.5432 81.2287 51.4699 75.1073 48.0565Z" fill="#FBB18C"/>
  </svg>
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
