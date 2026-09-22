import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _timerPermissionRequested = false;

  static bool get timerPermissionRequested => _timerPermissionRequested;

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(initializationSettings);
  }

  static Future<bool> requestTimerPermissions() async {
    _timerPermissionRequested = true;

    final iosGranted = await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final macosGranted = await _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final androidGranted = await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    return iosGranted ?? macosGranted ?? androidGranted ?? true;
  }

  static Future<void> scheduleTimerNotification({
    required int seconds,
    required String recipeName,
    required int stepNumber,
  }) async {
    final scheduledDate = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: seconds));

    const androidDetails = AndroidNotificationDetails(
      'cooking_timer',
      'Cooking Timer',
      channelDescription: 'Notifications for cooking timer completion',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      0, // Notification ID
      'Timer Done! ⏰',
      'Step $stepNumber for $recipeName is ready',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    print('✅ Notification scheduled for $seconds seconds from now');
  }

  static Future<void> showTimerDoneNotification(
    String recipeName,
    int stepNumber,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'cooking_timer',
      'Cooking Timer',
      channelDescription: 'Notifications for cooking timer completion',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'Timer Done! ⏰',
      'Step $stepNumber for $recipeName is ready',
      notificationDetails,
    );
  }

  static Future<void> showTimerCompleteNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Cooking Timers',
      channelDescription: 'Notifications for cooking timer completions',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1, // Different ID from showTimerDoneNotification
      title,
      body,
      notificationDetails,
    );
  }

  static Future<void> cancelScheduledNotifications() async {
    await _notifications.cancel(0);
  }
}
