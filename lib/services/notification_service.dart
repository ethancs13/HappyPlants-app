import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // v2 channel includes the custom sound — Android ties sound to the channel,
  // so a new channel ID is required for existing installs to pick it up.
  static const _channelId = 'watering_reminders_v2';
  static const _channelName = 'Watering Reminders';
  static const _channelDesc = 'Daily reminders when a plant needs watering';

  // Custom sound — file must exist at android/app/src/main/res/raw/water_notification.mp3
  // and be added to ios/Runner in Xcode (Copy Bundle Resources) for iOS.
  static const _sound = RawResourceAndroidNotificationSound('water_notification');

  static const defaultNotifyHour = 9;
  static const defaultNotifyMinute = 0;

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

  /// Schedules a notification on the plant's next watering date at [notifyHour].
  /// Uses Dart's built-in local timezone so no extra plugin is needed.
  static Future<void> scheduleWateringReminder(
    Plant plant, {
    int notifyHour = defaultNotifyHour,
    int notifyMinute = defaultNotifyMinute,
  }) async {
    final next = plant.nextWateringDate;
    if (next == null || plant.id == null || !plant.notificationsEnabled) return;

    // Overdue plants have nextWateringDate in the past — remind today instead.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextDay = DateTime(next.year, next.month, next.day);
    final targetDay = nextDay.isAfter(today) ? nextDay : today;

    final localTime = DateTime(
        targetDay.year, targetDay.month, targetDay.day, notifyHour, notifyMinute);
    final utcTime = localTime.toUtc();

    final scheduled = tz.TZDateTime.utc(
        utcTime.year, utcTime.month, utcTime.day, utcTime.hour, utcTime.minute);

    // Skip if today's reminder window has already passed.
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
          sound: _sound,
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

  /// Cancels all pending notifications.
  static Future<void> cancelAll() => _plugin.cancelAll();

  /// Cancels all notifications and reschedules for every plant in the list.
  /// Called on app startup and when the reminder time changes.
  static Future<void> rescheduleAll(
    List<Plant> plants, {
    int notifyHour = defaultNotifyHour,
    int notifyMinute = defaultNotifyMinute,
  }) async {
    await _plugin.cancelAll();
    for (final plant in plants) {
      await scheduleWateringReminder(plant, notifyHour: notifyHour, notifyMinute: notifyMinute);
    }
  }

  /// Fires an immediate test notification so the user can verify reminders work.
  static Future<void> sendTestNotification() async {
    await _plugin.show(
      0,
      'Reminders are working!',
      'Your watering reminders are set up correctly.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: _sound,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
