import 'package:flutter/material.dart';

/// Notification frequency options
enum NotificationFrequency { daily, weekdaysOnly, weekendsOnly, custom }

/// Notification timing strategy
enum NotificationTiming {
  /// Fixed time notification (user-selected time)
  fixedTime,

  /// Ritual window-based notifications (morning, afternoon, evening)
  ritualWindows,
}

/// User notification preferences
class NotificationPreferences {
  final bool enabled;
  final TimeOfDay time;
  final NotificationFrequency frequency;
  final NotificationTiming timing;
  final List<int> customDays; // 1-7 (Monday-Sunday) for custom frequency

  // Granular controls for ritual windows
  final bool morningEnabled;
  final bool afternoonEnabled;
  final bool eveningEnabled;

  // Custom times for each window
  final TimeOfDay morningTime;
  final TimeOfDay afternoonTime;
  final TimeOfDay eveningTime;

  const NotificationPreferences({
    this.enabled = false,
    this.time = const TimeOfDay(hour: 16, minute: 0),
    this.frequency = NotificationFrequency.daily,
    this.timing = NotificationTiming.fixedTime,
    this.customDays = const [],
    this.morningEnabled = true,
    this.afternoonEnabled = true,
    this.eveningEnabled = true,
    this.morningTime = const TimeOfDay(hour: 8, minute: 0),
    this.afternoonTime = const TimeOfDay(hour: 14, minute: 0),
    this.eveningTime = const TimeOfDay(hour: 20, minute: 0),
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': time.hour,
    'minute': time.minute,
    'frequency': frequency.index,
    'timing': timing.index,
    'customDays': customDays,
    'morningEnabled': morningEnabled,
    'afternoonEnabled': afternoonEnabled,
    'eveningEnabled': eveningEnabled,
    'morningHour': morningTime.hour,
    'morningMinute': morningTime.minute,
    'afternoonHour': afternoonTime.hour,
    'afternoonMinute': afternoonTime.minute,
    'eveningHour': eveningTime.hour,
    'eveningMinute': eveningTime.minute,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enabled: json['enabled'] as bool? ?? false,
      time: TimeOfDay(
        hour: json['hour'] as int? ?? 16,
        minute: json['minute'] as int? ?? 0,
      ),
      frequency: NotificationFrequency.values[json['frequency'] as int? ?? 0],
      timing: NotificationTiming.values[json['timing'] as int? ?? 0],
      customDays:
          (json['customDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      morningEnabled: json['morningEnabled'] as bool? ?? true,
      afternoonEnabled: json['afternoonEnabled'] as bool? ?? true,
      eveningEnabled: json['eveningEnabled'] as bool? ?? true,
      morningTime: TimeOfDay(
        hour: json['morningHour'] as int? ?? 8,
        minute: json['morningMinute'] as int? ?? 0,
      ),
      afternoonTime: TimeOfDay(
        hour: json['afternoonHour'] as int? ?? 14,
        minute: json['afternoonMinute'] as int? ?? 0,
      ),
      eveningTime: TimeOfDay(
        hour: json['eveningHour'] as int? ?? 20,
        minute: json['eveningMinute'] as int? ?? 0,
      ),
    );
  }

  NotificationPreferences copyWith({
    bool? enabled,
    TimeOfDay? time,
    NotificationFrequency? frequency,
    NotificationTiming? timing,
    List<int>? customDays,
    bool? morningEnabled,
    bool? afternoonEnabled,
    bool? eveningEnabled,
    TimeOfDay? morningTime,
    TimeOfDay? afternoonTime,
    TimeOfDay? eveningTime,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      time: time ?? this.time,
      frequency: frequency ?? this.frequency,
      timing: timing ?? this.timing,
      customDays: customDays ?? this.customDays,
      morningEnabled: morningEnabled ?? this.morningEnabled,
      afternoonEnabled: afternoonEnabled ?? this.afternoonEnabled,
      eveningEnabled: eveningEnabled ?? this.eveningEnabled,
      morningTime: morningTime ?? this.morningTime,
      afternoonTime: afternoonTime ?? this.afternoonTime,
      eveningTime: eveningTime ?? this.eveningTime,
    );
  }
}
