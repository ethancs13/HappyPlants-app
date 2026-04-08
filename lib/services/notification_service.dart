import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'watering_reminders';
  static const _channelName = 'Watering Reminders';
  static const _channelDesc = 'Daily reminders when a plant needs watering';

  // Hour of day to deliver watering reminders (9 AM local time)
  static const _notifyHour = 9;

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
    );

    // Request Android 13+ POST_NOTIFICATIONS permission
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Schedules a 9 AM notification on the plant's next watering date.
  /// Uses Dart's built-in local timezone so no extra plugin is needed.
  static Future<void> scheduleWateringReminder(Plant plant) async {
    final next = plant.nextWateringDate;
    if (next == null || plant.id == null) return;

    // Build 9 AM in local time on the due date, then convert to UTC.
    // Dart's DateTime() (without .utc) reads the device's local timezone.
    final local9am =
        DateTime(next.year, next.month, next.day, _notifyHour, 0);
    final utc9am = local9am.toUtc();

    // TZDateTime.utc represents the exact moment; the device fires the
    // notification at that instant, which equals 9 AM in the user's timezone.
    final scheduled = tz.TZDateTime.utc(
        utc9am.year, utc9am.month, utc9am.day, utc9am.hour, utc9am.minute);

    if (scheduled.isBefore(tz.TZDateTime.now(tz.UTC))) return;

    await _plugin.zonedSchedule(
      plant.id!,
      '${plant.name} needs water today',
      plant.species.isNotEmpty
          ? 'Time to water your ${plant.species}!'
          : "Don't forget to water your plant!",
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancels the pending notification for the given plant.
  static Future<void> cancelReminder(int plantId) async {
    await _plugin.cancel(plantId);
  }

  /// Cancels all notifications and reschedules for every plant in the list.
  /// Called on app startup so notifications always reflect current DB state.
  static Future<void> rescheduleAll(List<Plant> plants) async {
    await _plugin.cancelAll();
    for (final plant in plants) {
      await scheduleWateringReminder(plant);
    }
  }
}
