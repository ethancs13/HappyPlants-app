/// One entry per Figma houseplant illustration.
///
/// [key]   asset name prefix, e.g. 'plant_01'
///           assets/images/plants/plant_01_foliage.svg
///           assets/images/plants/plant_01_pot.svg
/// [label] shown in the plant picker grid
class PlantImage {
  final String key;
  final String label;

  const PlantImage({required this.key, required this.label});
}

const List<PlantImage> kPlantImages = [
  PlantImage(key: 'plant_01', label: 'Vine'),
  PlantImage(key: 'plant_02', label: 'Snake Plant'),
  PlantImage(key: 'plant_03', label: 'Cactus'),
  PlantImage(key: 'plant_04', label: 'Wavy Leaf'),
  PlantImage(key: 'plant_05', label: 'Pancake Plant'),
  PlantImage(key: 'plant_06', label: 'Barrel Cactus'),
  PlantImage(key: 'plant_07', label: 'Trailing'),
  PlantImage(key: 'plant_08', label: 'Bowl Garden'),
  PlantImage(key: 'plant_09', label: 'Big Leaf'),
  PlantImage(key: 'plant_10', label: 'Oak Leaf'),
  PlantImage(key: 'plant_11', label: 'Oak Bunch'),
  PlantImage(key: 'plant_12', label: 'Leafy Vine'),
  PlantImage(key: 'plant_13', label: 'Leafy Bush'),
  PlantImage(key: 'plant_14', label: 'Monstera'),
  PlantImage(key: 'plant_15', label: 'Tea Plant'),
];
