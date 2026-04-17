import 'package:flutter/material.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:happy_plants/screens/add_plant_screen.dart';
import 'package:happy_plants/screens/home_screen.dart';
import 'package:happy_plants/screens/plant_detail_screen.dart';
import 'package:happy_plants/services/notification_service.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global theme notifier — read by [HappyPlantsApp], written by SettingsScreen.
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  final prefs = await SharedPreferences.getInstance();

  // Restore saved theme preference.
  final savedTheme = prefs.getString('theme_mode');
  if (savedTheme == 'light') {
    themeNotifier.value = ThemeMode.light;
  } else if (savedTheme == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  } else {
    themeNotifier.value = ThemeMode.system;
  }

  // Reschedule all notifications on startup.
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
  if (notificationsEnabled) {
    final notifyHour =
        prefs.getInt('reminder_hour') ?? NotificationService.defaultNotifyHour;
    final notifyMinute = prefs.getInt('reminder_minute') ??
        NotificationService.defaultNotifyMinute;
    final repo = await PlantRepository.create();
    final plants = await repo.getAll();
    await NotificationService.rescheduleAll(
      plants,
      notifyHour: notifyHour,
      notifyMinute: notifyMinute,
    );
  }

  runApp(const HappyPlantsApp());
}

class HappyPlantsApp extends StatelessWidget {
  const HappyPlantsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) => MaterialApp(
        title: 'HappyPlants',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
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
      ),
    );
  }
}
