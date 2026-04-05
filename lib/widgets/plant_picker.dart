import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:happy_plants/models/plant_images.dart';
import 'package:happy_plants/theme/app_theme.dart';

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
          color: selected ? AppColors.statusGreenBg : AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: _PlantPreview(plantKey: plant.key),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                plant.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.forest : AppColors.textMuted,
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

/// Static preview stacking foliage behind pot.
/// Shows a placeholder icon while SVG assets are not yet present.
class _PlantPreview extends StatelessWidget {
  final String plantKey;

  const _PlantPreview({required this.plantKey});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final foliagePath = 'assets/images/plants/${plantKey}_foliage.svg';
        final potPath = 'assets/images/plants/${plantKey}_pot.svg';

        Widget placeholder(bool isMain) => isMain
            ? Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.eco_outlined, color: AppColors.olive),
              )
            : const SizedBox.shrink();

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              SvgPicture.asset(
                foliagePath,
                width: size,
                height: size,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => placeholder(true),
              ),
              SvgPicture.asset(
                potPath,
                width: size,
                height: size,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => placeholder(false),
              ),
            ],
          ),
        );
      },
    );
  }
}
