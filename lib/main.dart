import 'package:flutter/material.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/screens/add_plant_screen.dart';
import 'package:happy_plants/screens/home_screen.dart';
import 'package:happy_plants/screens/plant_detail_screen.dart';
import 'package:happy_plants/theme/app_theme.dart';

void main() {
  runApp(const HappyPlantsApp());
}

class HappyPlantsApp extends StatelessWidget {
  const HappyPlantsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HappyPlants',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/add':
            return MaterialPageRoute(
              builder: (_) => const AddPlantScreen(),
            );
          case '/detail':
            final plant = settings.arguments as Plant;
            return MaterialPageRoute(
              builder: (_) => PlantDetailScreen(plant: plant),
            );
          default:
            return null;
        }
      },
    );
  }
}
