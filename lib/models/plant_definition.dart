/// Describes one visual part of a plant (a leaf, stem, or pot).
///
/// Coordinates are in native canvas units. The canvas origin is
/// bottom-left (left=0, bottom=0) to make it easier to think about
/// leaf heights. [PlantWidget] converts this to Flutter's top-left
/// origin before rendering.
class PlantPart {
  /// Asset path relative to the Flutter asset root,
  /// e.g. 'assets/images/plants/plant_02/leaf-0.svg'
  final String asset;

  /// Natural width / height of this SVG in canvas units (usually its
  /// actual pixel size from Figma).
  final double width;
  final double height;

  /// Distance from the LEFT edge of the canvas to the LEFT edge of
  /// this part's bounding box.
  final double left;

  /// Distance from the BOTTOM edge of the canvas to the BOTTOM edge
  /// of this part's bounding box.
  final double bottom;

  /// Maximum sway rotation in radians (happy state).
  /// 0 = static (use for pot / base elements).
  final double happyAmplitude;

  /// Fraction (0.0–1.0) of the full animation cycle at which this
  /// part starts swaying. Spread across leaves for a wave effect.
  final double phaseOffset;

  /// Constant rotation offset in radians applied on top of the sway.
  /// Positive = clockwise. Use to tilt a part without editing the SVG.
  final double baseAngle;

  /// Sway pivot expressed as Flutter Alignment within this part.
  /// Alignment.bottomCenter = part sways from its own base.
  final Object swayAlignment; // Alignment

  const PlantPart({
    required this.asset,
    required this.width,
    required this.height,
    required this.left,
    required this.bottom,
    this.happyAmplitude = 0.0,
    this.phaseOffset = 0.0,
    this.baseAngle = 0.0,
    this.swayAlignment = const _BottomCenter(),
  });
}

// Simple value classes to avoid importing flutter in a plain model file.
class _BottomCenter {
  const _BottomCenter();
}

class _BottomLeft {
  const _BottomLeft();
}

class _BottomRight {
  const _BottomRight();
}


/// Full layout definition for one plant.
class PlantDefinition {
  /// Native canvas width in logical pixels (before [PlantWidget] scaling).
  final double canvasWidth;

  /// Native canvas height in logical pixels.
  final double canvasHeight;

  /// Parts ordered back-to-front (first = furthest behind).
  final List<PlantPart> parts;

  const PlantDefinition({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.parts,
  });
}

// ---------------------------------------------------------------------------
// Plant definitions
// ---------------------------------------------------------------------------

// Vine houseplant — 3 branches (left, middle, right) + pot (TBD)
//
// Native canvas: 280 × 300
// All branch roots converge at approx (140, 20) from canvas bottom-left.
// Branch sizes from Figma export:
//   left-branch:   138 × 201  (root at bottom-right of SVG)
//   middle-branch:  62 × 246  (root at bottom-center of SVG)
//   right-branch:  138 × 201  (root at bottom-left of SVG)
//
// left=2   places left-branch root at x=140
// left=109 places middle-branch root at x=140
// left=140 places right-branch root at x=140
const _vineHouseplant = PlantDefinition(
  canvasWidth: 280,
  canvasHeight: 300,
  parts: [
    // Left branch — root at bottom-right of its SVG
    PlantPart(
      asset: 'assets/images/plants/plant_01/left-branch.svg',
      width: 138, height: 201,
      left: 2, bottom: 46,
      happyAmplitude: 0.03, phaseOffset: 0.07,
      swayAlignment: _BottomRight(),
    ),
    // Right branch — root at bottom-left of its SVG
    PlantPart(
      asset: 'assets/images/plants/plant_01/right-branch.svg',
      width: 138, height: 201,
      left: 140, bottom: 46,
      happyAmplitude: 0.03, phaseOffset: 0.07,
      swayAlignment: _BottomLeft(),
    ),
    // Middle branch — root at bottom-center
    PlantPart(
      asset: 'assets/images/plants/plant_01/middle-branch.svg',
      width: 62, height: 246,
      left: 109, bottom: 46,
      happyAmplitude: 0.03, phaseOffset: 0.0,
    ),
    // Pot — reuse snake plant pot (static)
    PlantPart(
      asset: 'assets/images/plants/plant_02/pot.svg',
      width: 120, height: 105,
      left: 80, bottom: 0,
      happyAmplitude: 0.0,
    ),
  ],
);

// Pancake plant (plant_05) — 5 stem-leaves radiating from a central root + shared pot
//
// Native canvas: 360 × 320
// All stem roots converge at canvas (170, ~20).
//
// Stem sizes and root positions (SVG coords):
//   stem-leaf-0: 168×160  root at SVG (166, 159) → bottom-right  → left=4,   bottom=20
//   stem-leaf-1: 140×260  root at SVG (136, 259) → bottom-right  → left=34,  bottom=20
//   stem-leaf-2:  88×266  root at SVG ( 26, 265) → bottom-center → left=144, bottom=20
//   stem-leaf-3: 139×232  root at SVG (  0, 231) → bottom-left   → left=170, bottom=20
//   stem-leaf-4: 186×132  root at SVG (  0, 130) → bottom-left   → left=170, bottom=20
//
// Pot (120×105) centered at x=170: left=110, bottom=0
const _pancakePlant = PlantDefinition(
  canvasWidth: 360,
  canvasHeight: 320,
  parts: [
    // Outer left stem — behind everything on the left
    PlantPart(
      asset: 'assets/images/plants/plant_05/stem-leaf-0.svg',
      width: 168, height: 160,
      left: 0, bottom: 57,
      happyAmplitude: 0.03, phaseOffset: 0.14,
      swayAlignment: _BottomRight(),
    ),
    // Outer right stem — behind everything on the right
    PlantPart(
      asset: 'assets/images/plants/plant_05/stem-leaf-4.svg',
      width: 186, height: 132,
      left: 165, bottom: 65,
      happyAmplitude: 0.03, phaseOffset: 0.14,
      swayAlignment: _BottomLeft(),
    ),
    // Inner left stem
    PlantPart(
      asset: 'assets/images/plants/plant_05/stem-leaf-1.svg',
      width: 140, height: 260,
      left: 24, bottom: 45,
      happyAmplitude: 0.03, phaseOffset: 0.07,
      swayAlignment: _BottomRight(),
    ),
    // Inner right stem
    PlantPart(
      asset: 'assets/images/plants/plant_05/stem-leaf-3.svg',
      width: 139, height: 232,
      left: 180, bottom: 60,
      happyAmplitude: 0.03, phaseOffset: 0.07,
      swayAlignment: _BottomLeft(),
    ),
    // Center stem — front
    PlantPart(
      asset: 'assets/images/plants/plant_05/stem-leaf-2.svg',
      width: 88, height: 266,
      left: 134, bottom: 60,
      happyAmplitude: 0.03, phaseOffset: 0.0,
    ),
    // Pot — reuse snake plant pot (static)
    PlantPart(
      asset: 'assets/images/plants/plant_02/pot.svg',
      width: 120, height: 105,
      left: 110, bottom: 0,
      happyAmplitude: 0.0,
    ),
  ],
);

// Trailing plant (plant_07) — 2 branches from a shared root + shared pot
//
// Native canvas: 310 × 340
// branch-0 root at canvas x=100, branch-1 root at canvas x=125 (25px spread).
//
// Branch sizes and root positions (SVG coords):
//   branch-0: 121×285  root at SVG ( 97, 284) → bottom-right → left=3,   bottom=70
//   branch-1: 185×301  root at SVG ( 13, 300) → bottom-left  → left=112, bottom=63
//
// branch-0 curves up-left, branch-1 curves up-right
// Pot (120×105) centered between roots x=112: left=52, bottom=0
const _trailingPlant = PlantDefinition(
  canvasWidth: 310,
  canvasHeight: 340,
  parts: [
    // branch-0 — curves left, behind
    PlantPart(
      asset: 'assets/images/plants/plant_07/branch-0.svg',
      width: 121, height: 285,
      left: 10, bottom: 70,
      happyAmplitude: 0.03, phaseOffset: 0.07,
      swayAlignment: _BottomRight(),
    ),
    // branch-1 — curves right, front
    PlantPart(
      asset: 'assets/images/plants/plant_07/branch-1.svg',
      width: 185, height: 301,
      left: 114, bottom: 63,
      happyAmplitude: 0.03, phaseOffset: 0.0,
      swayAlignment: _BottomLeft(),
    ),
    // Pot — reuse snake plant pot (static)
    PlantPart(
      asset: 'assets/images/plants/plant_02/pot.svg',
      width: 120, height: 105,
      left: 72, bottom: 0,
      happyAmplitude: 0.0,
    ),
  ],
);

// Tea plant (plant_15) — single stem-and-leaves element + shared pot
//
// Native canvas: 200 × 320
// Root at SVG (93, 285) ≈ bottom-center of the 194×286 SVG.
// left=7 places root at canvas x=100 (center).
// Pot (120×105) centered at x=100: left=40, bottom=0
const _teaPlant = PlantDefinition(
  canvasWidth: 200,
  canvasHeight: 320,
  parts: [
    PlantPart(
      asset: 'assets/images/plants/plant_15/stem-and-leaves.svg',
      width: 194, height: 286,
      left: 7, bottom: 20,
      happyAmplitude: 0.03, phaseOffset: 0.0,
    ),
    PlantPart(
      asset: 'assets/images/plants/plant_02/pot.svg',
      width: 120, height: 105,
      left: 40, bottom: 0,
      happyAmplitude: 0.0,
    ),
  ],
);

// Monstera (plant_14) — 4 stems + shared pot
//
// Native canvas: 265 × 340
// Stems 0&1 roots at canvas x=115, stems 2&3 roots at canvas x=145 (30px separation).
//
// Stem sizes and root positions (SVG coords):
//   stem-0: 131×237  root at SVG (113, 236) → bottom-right → left=2,   bottom=32  (30%)
//   stem-1: 121×254  root at SVG ( 91, 253) → bottom-right → left=24,  bottom=48  (46%)
//   stem-2: 127×266  root at SVG ( 17, 265) → bottom-left  → left=128, bottom=59  (56%)
//   stem-3: 131×237  root at SVG ( 17, 236) → bottom-left  → left=128, bottom=64  (61%)
//
// Pot (120×105) centered between root groups x=130: left=70, bottom=0
const _monsteraPlant = PlantDefinition(
  canvasWidth: 265,
  canvasHeight: 340,
  parts: [
    // stem-3 — outer left, furthest back; tilted clockwise and shifted right
    PlantPart(
      asset: 'assets/images/plants/plant_14/stem-3.svg',
      width: 131, height: 237,
      left: 130, bottom: 44,
      happyAmplitude: 0.03, phaseOffset: 0.14,
      baseAngle: 0.15,
      swayAlignment: _BottomLeft(),
    ),
    // stem-1 — behind stem-0
    PlantPart(
      asset: 'assets/images/plants/plant_14/stem-1.svg',
      width: 121, height: 254,
      left: 24, bottom: 48,
      happyAmplitude: 0.03, phaseOffset: 0.07,
      swayAlignment: _BottomRight(),
    ),
    // stem-0 — in front of stem-1
    PlantPart(
      asset: 'assets/images/plants/plant_14/stem-0.svg',
      width: 131, height: 237,
      left: -20, bottom: 22,
      happyAmplitude: 0.03, phaseOffset: 0.14,
      swayAlignment: _BottomRight(),
    ),
    // stem-2 — inner left, front
    PlantPart(
      asset: 'assets/images/plants/plant_14/stem-2.svg',
      width: 127, height: 266,
      left: 134, bottom: 59,
      happyAmplitude: 0.03, phaseOffset: 0.07,
      swayAlignment: _BottomLeft(),
    ),
    // Pot — reuse snake plant pot (static)
    PlantPart(
      asset: 'assets/images/plants/plant_02/pot.svg',
      width: 144, height: 126,
      left: 58, bottom: 0,
      happyAmplitude: 0.0,
    ),
  ],
);

// Cactus (plant_03) — single cactus body + own pot
//
// Native canvas: 210 × 340
// Cactus base centered at SVG x≈65, bottom of SVG at canvas y=20 (inside pot).
// left=9 places base center at canvas x=74.
// Pot (120×105) centered at x=74: left=14, bottom=0
const _cactusPlant = PlantDefinition(
  canvasWidth: 210,
  canvasHeight: 340,
  parts: [
    PlantPart(
      asset: 'assets/images/plants/plant_03/cactus.svg',
      width: 130, height: 210,
      left: 52, bottom: 85,
      happyAmplitude: 0.02, phaseOffset: 0.0,
    ),
    PlantPart(
      asset: 'assets/images/plants/plant_03/pot.svg',
      width: 120, height: 105,
      left: 43, bottom: 0,
      happyAmplitude: 0.0,
    ),
  ],
);

/// All plant definitions keyed by plantKey (e.g. 'plant_02').
const Map<String, PlantDefinition> kPlantDefinitions = {
  'plant_01': _vineHouseplant,
  'plant_02': _snakePlant,
  'plant_03': _cactusPlant,
  'plant_05': _pancakePlant,
  'plant_07': _trailingPlant,
  'plant_14': _monsteraPlant,
  'plant_15': _teaPlant,
};

// Snake plant — 8 leaves (0=leftmost … 7=rightmost) + pot
//
// Native canvas: 200 × 280
// Pot (120×105) centered at bottom: left=40, bottom=0
// Leaf bases at bottom=105 (top of the pot), spread across x=40–160
//
// Leaf sizes from Figma export:
//   0: 42×199   1: 55×220   2: 35×241   3: 22×177
//   4: 21×177   5: 35×241   6: 56×220   7: 43×199
//
// Horizontal centres evenly spaced: 51, 68, 82, 93, 107, 118, 132, 149
// Amplitudes: outer ±0.16 → inner ±0.05 (happy), sad = 30% of happy
const _snakePlant = PlantDefinition(
  canvasWidth: 200,
  canvasHeight: 280,
  parts: [
    // Back leaves first (outer pair behind inner pair)
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-0.svg', width: 42, height: 199, left: 44,  bottom: 55, happyAmplitude: 0.03, phaseOffset: 0.20),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-7.svg', width: 43, height: 199, left: 114, bottom: 55, happyAmplitude: 0.03, phaseOffset: 0.20),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-1.svg', width: 55, height: 220, left: 54,  bottom: 55, happyAmplitude: 0.03, phaseOffset: 0.13),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-6.svg', width: 56, height: 220, left: 92,  bottom: 55, happyAmplitude: 0.03, phaseOffset: 0.13),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-2.svg', width: 35, height: 241, left: 68,  bottom: 55, happyAmplitude: 0.03, phaseOffset: 0.07),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-5.svg', width: 35, height: 241, left: 98,  bottom: 55, happyAmplitude: 0.03, phaseOffset: 0.07),
    // Inner (front) leaves — almost on top of one another
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-3.svg', width: 22, height: 177, left: 87,  bottom: 55, happyAmplitude: 0.03, phaseOffset: 0.0),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-4.svg', width: 21, height: 177, left: 89,  bottom: 55, happyAmplitude: 0.03, phaseOffset: 0.0),
    // Pot — static (happyAmplitude = 0)
    PlantPart(asset: 'assets/images/plants/plant_02/pot.svg',    width: 120, height: 105, left: 40, bottom: 0,   happyAmplitude: 0.00),
  ],
);
