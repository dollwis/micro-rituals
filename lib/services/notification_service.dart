import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';

/// Notification Service for daily ritual reminders
/// Note: Notifications are not supported on web platform
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _reminderTimeKey = 'reminder_time_hour';
  static const String _reminderMinuteKey = 'reminder_time_minute';
  static const String _notificationsEnabledKey = 'notifications_enabled';

  // Default reminder time: 4:00 PM
  static const int _defaultHour = 16;
  static const int _defaultMinute = 0;
  
  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Skip initialization on web - notifications not supported
    if (kIsWeb) {
      debugPrint('NotificationService: Skipping init on web platform');
      return;
    }
    
    if (_initialized) return;
    
    try {
      // Initialize timezone
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.UTC);

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService: Failed to initialize - $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Request notification permission (call on first launch)
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    
    // iOS
    final iosGranted = await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Android 13+
    final androidGranted = await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    return iosGranted ?? androidGranted ?? true;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? false;
  }

  /// Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);

    if (kIsWeb) return;
    
    if (enabled) {
      await scheduleDailyReminder();
    } else {
      await cancelAllNotifications();
    }
  }

  /// Get saved reminder time
  Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_reminderTimeKey) ?? _defaultHour;
    final minute = prefs.getInt(_reminderMinuteKey) ?? _defaultMinute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Save reminder time and reschedule
  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderTimeKey, time.hour);
    await prefs.setInt(_reminderMinuteKey, time.minute);

    if (kIsWeb) return;
    
    // Reschedule with new time
    final enabled = await areNotificationsEnabled();
    if (enabled) {
      await scheduleDailyReminder();
    }
  }

  /// Schedule daily recurring reminder
  Future<void> scheduleDailyReminder() async {
    if (kIsWeb) return;
    
    await cancelAllNotifications();

    final time = await getReminderTime();
    final scheduledTime = _nextInstanceOfTime(time.hour, time.minute);

    await _notifications.zonedSchedule(
      0, // Notification ID
      'Daily Micro-Ritual',
      'Time for your daily micro-ritual. Just 5 minutes to reset your mind.',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Reminder',
          channelDescription: 'Daily ritual reminder notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Daily repeat
      payload: 'daily_ritual',
    );
  }

  /// Get next instance of the specified time
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }
}
