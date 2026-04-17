import 'package:flutter/material.dart';
import 'package:happy_plants/models/plant_images.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:happy_plants/widgets/plant_widget.dart';

/// Scrollable 3-column grid of all 15 plant illustrations.
/// [selectedKey] is the currently selected key (e.g. 'plant_03'), or null.
/// [onSelected] fires with the key when a tile is tapped.
class PlantPicker extends StatelessWidget {
  final String? selectedKey;
  final void Function(String key) onSelected;

  const PlantPicker({
    super.key,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kPlantImages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, i) {
        final plant = kPlantImages[i];
        return _PlantTile(
          plant: plant,
          selected: plant.key == selectedKey,
          onTap: () => onSelected(plant.key),
        );
      },
    );
  }
}

class _PlantTile extends StatelessWidget {
  final PlantImage plant;
  final bool selected;
  final VoidCallback onTap;

  const _PlantTile({
    required this.plant,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? context.col.statusGreenBg : context.col.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.forest : context.col.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: PlantWidget(
                  isHappy: true,
                  isStatic: !selected,
                  size: 56,
                  plantKey: plant.key,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                plant.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.forest : context.col.textMuted,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

