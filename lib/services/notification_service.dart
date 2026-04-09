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

  // Custom sound — file must exist at android/app/src/main/res/raw/watering_reminder.mp3
  // and be added to ios/Runner in Xcode (Copy Bundle Resources) for iOS.
  static const _sound = RawResourceAndroidNotificationSound('watering_reminder');

  // Default hour of day to deliver watering reminders (9 AM local time)
  static const defaultNotifyHour = 9;

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
  }) async {
    final next = plant.nextWateringDate;
    if (next == null || plant.id == null || !plant.notificationsEnabled) return;

    // Build the target time in local time on the due date, then convert to UTC.
    // Dart's DateTime() (without .utc) reads the device's local timezone.
    final localTime = DateTime(next.year, next.month, next.day, notifyHour, 0);
    final utcTime = localTime.toUtc();

    // TZDateTime.utc represents the exact moment; the device fires the
    // notification at that instant, which equals 9 AM in the user's timezone.
    final scheduled = tz.TZDateTime.utc(
        utcTime.year, utcTime.month, utcTime.day, utcTime.hour, utcTime.minute);

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
  }) async {
    await _plugin.cancelAll();
    for (final plant in plants) {
      await scheduleWateringReminder(plant, notifyHour: notifyHour);
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
