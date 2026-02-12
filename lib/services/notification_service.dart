import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/notification_types.dart';
import '../models/ritual_window_preferences.dart';

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
  static const String _notificationPrefsKey = 'notification_preferences';

  // Default reminder time: 4:00 PM
  static const int _defaultHour = 16;
  static const int _defaultMinute = 0;

  bool _initialized = false;

  // Pool of motivational notification messages
  static const List<String> _motivationalMessages = [
    'Time for your daily micro-ritual. Just 5 minutes to reset your mind.',
    'Your moment of mindfulness awaits.',
    'Take a conscious breath. Your ritual is ready.',
    'Pause. Breathe. Reset. Your daily ritual begins now.',
    'Five minutes of stillness can transform your day.',
    'Your mind deserves this moment of peace.',
    'Step into your ritual. Step into calm.',
    'Today\'s micro-ritual: A gift to yourself.',
    'Reconnect with yourself. Your ritual awaits.',
    'Small rituals, profound change. Begin now.',
  ];

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
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == true) {
        debugPrint('NotificationService: Local notifications initialized');
        _createNotificationChannel();
        // Request permissions immediately on Android 13+
        await requestPermission();
        // Request exact alarm permission (Android 12+)
        await requestExactAlarmsPermission();
      } else {
        debugPrint(
          'NotificationService: Local notifications failed to initialize',
        );
      }

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService: Failed to initialize - $e');
    }
  }

  /// Create the notification channel (Android)
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ritual_windows', // id
      'Ritual Window Reminders', // title
      description: 'Notifications for ritual window times', // description
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
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
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android 13+
    final androidGranted = await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
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

    debugPrint('NotificationService: Scheduling daily reminder for $time');

    await _notifications.zonedSchedule(
      0, // Notification ID
      'Daily Micro-Ritual',
      _getRandomMotivationalMessage(),
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
    debugPrint('NotificationService: Daily reminder scheduled');
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
      debugPrint(
        'NotificationService: Time $hour:$minute passed for today (${scheduledDate} < ${now}), scheduling for tomorrow',
      );
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    } else {
      debugPrint('NotificationService: Scheduling for today at $scheduledDate');
    }

    return scheduledDate;
  }

  // ============ NEW ENHANCED FEATURES ============

  /// Get random motivational message from pool
  String _getRandomMotivationalMessage() {
    final random = Random();
    return _motivationalMessages[random.nextInt(_motivationalMessages.length)];
  }

  /// Get notification preferences
  Future<NotificationPreferences> getNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsJson = prefs.getString(_notificationPrefsKey);

    if (prefsJson == null) {
      // Return default preferences
      final time = await getReminderTime();
      return NotificationPreferences(
        enabled: await areNotificationsEnabled(),
        time: time,
      );
    }

    return NotificationPreferences.fromJson(json.decode(prefsJson));
  }

  /// Save notification preferences
  Future<void> setNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationPrefsKey,
      json.encode(preferences.toJson()),
    );

    // Also update legacy keys for backwards compatibility
    await prefs.setBool(_notificationsEnabledKey, preferences.enabled);
    await prefs.setInt(_reminderTimeKey, preferences.time.hour);
    await prefs.setInt(_reminderMinuteKey, preferences.time.minute);

    if (kIsWeb) return;

    // Reschedule notifications with new preferences
    if (preferences.enabled) {
      if (preferences.timing == NotificationTiming.ritualWindows) {
        await scheduleWindowBasedReminders(preferences);
      } else {
        await scheduleSmartReminder(preferences);
      }
    } else {
      await cancelAllNotifications();
    }
  }

  /// Schedule notifications based on ritual windows
  Future<void> scheduleWindowBasedReminders(
    NotificationPreferences preferences, {
    RitualWindowPreferences? windowPrefs,
  }) async {
    if (kIsWeb) return;

    // Ensure timezone is properly set
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      if (tz.local.name != timeZoneName) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      }
    } catch (e) {
      debugPrint('NotificationService: Error updating timezone: $e');
    }

    await cancelAllNotifications();

    // Fixed Window Definitions (End Times)
    // Morning ends at 12:00
    // Afternoon ends at 18:00
    // Evening ends at 04:00 (Next day)

    final windows = [
      {
        'type': 'morning',
        'hour': preferences.morningTime.hour,
        'minute': preferences.morningTime.minute,
        'isEnabled': preferences.morningEnabled,
        'windowEndHour': 12,
      },
      {
        'type': 'afternoon',
        'hour': preferences.afternoonTime.hour,
        'minute': preferences.afternoonTime.minute,
        'isEnabled': preferences.afternoonEnabled,
        'windowEndHour': 18,
      },
      {
        'type': 'evening',
        'hour': preferences.eveningTime.hour,
        'minute': preferences.eveningTime.minute,
        'isEnabled': preferences.eveningEnabled,
        'windowEndHour': 4, // Next day
      },
    ];

    int notificationId = 0;

    for (int i = 0; i < windows.length; i++) {
      final window = windows[i];
      final type = window['type'] as String;
      final isEnabled = window['isEnabled'] as bool;

      if (!isEnabled) continue;
      if (!_shouldScheduleForFrequency(preferences.frequency)) continue;

      final hour = window['hour'] as int;
      final minute = window['minute'] as int;
      final windowEndHour = window['windowEndHour'] as int;

      // Calculate scheduled time
      final scheduledTime = _nextInstanceOfTime(hour, minute);

      // Calculate timeout duration (Time until window ends)
      // We need to determine the actual end time relative to the scheduled time.
      // If windowEndHour < hour, it means the window ends on the next day relative to the scheduled time's date.
      // Example: scheduledTime: Today 20:00, windowEndHour: 4. End: Tomorrow 04:00.
      // Example: scheduledTime: Today 01:00, windowEndHour: 4. End: Today 04:00.

      final sTime = scheduledTime
          .toLocal(); // Ensure we work with local time parts
      DateTime endTime;
      DateTime candidateEnd = DateTime(
        sTime.year,
        sTime.month,
        sTime.day,
        windowEndHour,
      );
      if (candidateEnd.isBefore(sTime)) {
        candidateEnd = candidateEnd.add(const Duration(days: 1));
      }
      endTime = candidateEnd;

      final durationMs = endTime
          .difference(scheduledTime.toLocal())
          .inMilliseconds;
      if (durationMs <= 0) {
        debugPrint(
          'NotificationService: Skipping $type, calculated duration <= 0',
        );
        continue;
      }

      debugPrint(
        'NotificationService: Scheduling $type reminder for $hour:$minute at $scheduledTime (Timeout: ${durationMs}ms)',
      );

      try {
        await _notifications.zonedSchedule(
          notificationId + i, // Unique ID per window (0, 1, 2)
          'Ritual Window Open',
          '${_getRitualWindowLabel(TimeOfDay(hour: hour, minute: minute))} ${_getRandomMotivationalMessage()}',
          scheduledTime,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'ritual_windows',
              'Ritual Window Reminders',
              channelDescription: 'Notifications for ritual window times',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              timeoutAfter: durationMs, // Auto-cancel when window ends
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'ritual_window_$type',
        );
      } catch (e) {
        debugPrint('NotificationService: FAILED to schedule notification: $e');
      }
    }
    debugPrint('NotificationService: All enabled window reminders scheduled');
  }

  /// Schedule smart reminder based on frequency settings
  Future<void> scheduleSmartReminder(
    NotificationPreferences preferences,
  ) async {
    if (kIsWeb) return;
    await cancelAllNotifications();

    if (!_shouldScheduleForFrequency(preferences.frequency)) return;

    final scheduledTime = _nextInstanceOfTime(
      preferences.time.hour,
      preferences.time.minute,
    );
    debugPrint(
      'NotificationService: Scheduling smart reminder for $scheduledTime',
    );

    await _notifications.zonedSchedule(
      0,
      'Daily Micro-Ritual',
      _getRandomMotivationalMessage(),
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
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_ritual',
    );
    debugPrint('NotificationService: Smart reminder scheduled');
  }

  /// Check if notification should be scheduled based on frequency
  bool _shouldScheduleForFrequency(NotificationFrequency frequency) {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday

    switch (frequency) {
      case NotificationFrequency.daily:
        return true;
      case NotificationFrequency.weekdaysOnly:
        return weekday <= 5; // Monday-Friday
      case NotificationFrequency.weekendsOnly:
        return weekday > 5; // Saturday-Sunday
      case NotificationFrequency.custom:
        return true; // Custom days handled elsewhere
    }
  }

  /// Get ritual window label for notification
  String _getRitualWindowLabel(TimeOfDay time) {
    if (time.hour >= 4 && time.hour < 12) {
      return 'Morning Ritual:';
    } else if (time.hour >= 12 && time.hour < 17) {
      return 'Afternoon Reset:';
    } else {
      return 'Evening Wind-Down:';
    }
  }

  /// Request exact alarms permission (Android 12+)
  Future<void> requestExactAlarmsPermission() async {
    if (kIsWeb) return;

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Check if we can schedule exact notifications
    final bool? granted = await androidImplementation
        ?.requestExactAlarmsPermission();
    debugPrint(
      'NotificationService: Exact alarms permission granted: $granted',
    );
  }

  /// Send test notification (scheduled for 5 seconds later)
  Future<void> sendTestNotification() async {
    if (kIsWeb) return;

    debugPrint(
      'NotificationService: Scheduling test notification for 5 seconds from now',
    );

    // Ensure permission is checked before test
    await requestExactAlarmsPermission();

    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(seconds: 5));

    try {
      await _notifications.zonedSchedule(
        999, // Test notification ID
        'Test Notification (Scheduled)',
        'If you see this, scheduled notifications are working! ${_getRandomMotivationalMessage()}',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ritual_windows', // Use the SAME channel as real notifications
            'Ritual Window Reminders',
            channelDescription: 'Test notifications for settings',
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
        payload: 'test_scheduled',
      );
      debugPrint(
        'NotificationService: Test notification scheduled successfully',
      );
    } catch (e) {
      debugPrint(
        'NotificationService: FAILED to schedule test notification: $e',
      );
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // RITUAL WINDOW PREFERENCES
  // ───────────────────────────────────────────────────────────────────────────

  /// Get custom ritual window times
  Future<RitualWindowPreferences> getRitualWindowPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('ritual_window_prefs');
    if (json == null) {
      return RitualWindowPreferences.defaults;
    }
    return RitualWindowPreferences.fromJson(jsonDecode(json));
  }

  /// Set custom ritual window times
  Future<void> setRitualWindowPreferences(
    RitualWindowPreferences windowPrefs,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ritual_window_prefs',
      jsonEncode(windowPrefs.toJson()),
    );

    // Reschedule notifications to use new windows
    // Reschedule notifications to use new windows
    final notificationPrefs = await getNotificationPreferences();
    if (notificationPrefs.enabled) {
      if (notificationPrefs.timing != NotificationTiming.ritualWindows) {
        debugPrint('NotificationService: Switching timing to ritualWindows');
        // Update timing to ritualWindows
        final newNotifyPrefs = NotificationPreferences(
          enabled: true,
          time: notificationPrefs.time,
          frequency: notificationPrefs.frequency,
          timing: NotificationTiming.ritualWindows,
        );
        // This will save the new timing and trigger a reschedule
        await setNotificationPreferences(newNotifyPrefs);
        // Force reschedule with GUARANTEED correct window prefs
        await scheduleWindowBasedReminders(
          newNotifyPrefs,
          windowPrefs: windowPrefs,
        );
      } else {
        // Timing is correct, just reschedule with new window times
        await scheduleWindowBasedReminders(
          notificationPrefs,
          windowPrefs: windowPrefs,
        );
      }
    }
  }
}
