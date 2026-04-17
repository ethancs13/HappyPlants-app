import 'dart:io';
import 'package:flutter/material.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:happy_plants/widgets/plant_widget.dart';

class PlantCard extends StatelessWidget {
  final Plant plant;
  final VoidCallback onTap;
  final String? coverPhotoPath;

  const PlantCard({
    super.key,
    required this.plant,
    required this.onTap,
    this.coverPhotoPath,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = plant.isOverdueForWater;
    final nextDate = plant.nextWateringDate;

    String wateringLabel;
    if (plant.lastWateredDate == null) {
      wateringLabel = 'Not watered yet';
    } else if (overdue) {
      wateringLabel = 'Overdue for water';
    } else if (nextDate != null) {
      final daysLeft = nextDate.difference(DateTime.now()).inDays;
      if (daysLeft == 0) {
        wateringLabel = 'Water today';
      } else if (daysLeft == 1) {
        wateringLabel = 'Water tomorrow';
      } else {
        wateringLabel = 'Water in $daysLeft days';
      }
    } else {
      wateringLabel = 'No schedule';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 124,
        decoration: BoxDecoration(
          color: context.col.card,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            // Plant illustration / cover photo slot
            if (coverPhotoPath != null && File(coverPhotoPath!).existsSync())
              SizedBox(
                width: 92,
                height: double.infinity,
                child: Image.file(
                  File(coverPhotoPath!),
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 92,
                height: double.infinity,
                color: AppColors.potRim,
                child: Center(
                  child: PlantWidget(
                    isHappy: !overdue,
                    size: 72,
                    plantKey: plant.plantKey,
                  ),
                ),
              ),
            // Info section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      plant.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plant.species,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatusBadge(overdue: overdue),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            wateringLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool overdue;

  const _StatusBadge({required this.overdue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: overdue ? context.col.statusRedBg : context.col.statusGreenBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        overdue ? 'Overdue' : 'Good',
        style: TextStyle(
          color: overdue ? AppColors.statusRed : AppColors.statusGreen,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
