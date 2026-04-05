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
    this.swayAlignment = const _BottomCenter(),
  });
}

// Simple value class to avoid importing flutter in a plain model file.
class _BottomCenter {
  const _BottomCenter();
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

/// All plant definitions keyed by plantKey (e.g. 'plant_02').
const Map<String, PlantDefinition> kPlantDefinitions = {
  'plant_02': _snakePlant,
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
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-0.svg', width: 42, height: 199, left: 30,  bottom: 105, happyAmplitude: 0.16, phaseOffset: 0.00),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-7.svg', width: 43, height: 199, left: 128, bottom: 105, happyAmplitude: 0.16, phaseOffset: 0.50),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-1.svg', width: 55, height: 220, left: 41,  bottom: 105, happyAmplitude: 0.13, phaseOffset: 0.12),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-6.svg', width: 56, height: 220, left: 104, bottom: 105, happyAmplitude: 0.13, phaseOffset: 0.62),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-2.svg', width: 35, height: 241, left: 58,  bottom: 105, happyAmplitude: 0.09, phaseOffset: 0.25),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-5.svg', width: 35, height: 241, left: 107, bottom: 105, happyAmplitude: 0.09, phaseOffset: 0.75),
    // Inner (front) leaves
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-3.svg', width: 22, height: 177, left: 78,  bottom: 105, happyAmplitude: 0.05, phaseOffset: 0.37),
    PlantPart(asset: 'assets/images/plants/plant_02/leaf-4.svg', width: 21, height: 177, left: 100, bottom: 105, happyAmplitude: 0.05, phaseOffset: 0.87),
    // Pot — static (happyAmplitude = 0)
    PlantPart(asset: 'assets/images/plants/plant_02/pot.svg',    width: 120, height: 105, left: 40, bottom: 0,   happyAmplitude: 0.00),
  ],
);
