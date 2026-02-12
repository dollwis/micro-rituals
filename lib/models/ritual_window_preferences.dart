import 'package:flutter/material.dart';

/// Stores user's custom ritual window times for morning, afternoon, and evening
class RitualWindowPreferences {
  final TimeOfDay morningTime;
  final TimeOfDay afternoonTime;
  final TimeOfDay eveningTime;

  // Default times: 8am, 2pm, 7pm
  static const defaultMorning = TimeOfDay(hour: 8, minute: 0);
  static const defaultAfternoon = TimeOfDay(hour: 14, minute: 0);
  static const defaultEvening = TimeOfDay(hour: 19, minute: 0);

  const RitualWindowPreferences({
    this.morningTime = defaultMorning,
    this.afternoonTime = defaultAfternoon,
    this.eveningTime = defaultEvening,
  });

  /// Create from JSON (for SharedPreferences)
  factory RitualWindowPreferences.fromJson(Map<String, dynamic> json) {
    return RitualWindowPreferences(
      morningTime: TimeOfDay(
        hour: json['morning_hour'] as int? ?? defaultMorning.hour,
        minute: json['morning_minute'] as int? ?? defaultMorning.minute,
      ),
      afternoonTime: TimeOfDay(
        hour: json['afternoon_hour'] as int? ?? defaultAfternoon.hour,
        minute: json['afternoon_minute'] as int? ?? defaultAfternoon.minute,
      ),
      eveningTime: TimeOfDay(
        hour: json['evening_hour'] as int? ?? defaultEvening.hour,
        minute: json['evening_minute'] as int? ?? defaultEvening.minute,
      ),
    );
  }

  /// Convert to JSON (for SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'morning_hour': morningTime.hour,
      'morning_minute': morningTime.minute,
      'afternoon_hour': afternoonTime.hour,
      'afternoon_minute': afternoonTime.minute,
      'evening_hour': eveningTime.hour,
      'evening_minute': eveningTime.minute,
    };
  }

  /// Create a copy with updated fields
  RitualWindowPreferences copyWith({
    TimeOfDay? morningTime,
    TimeOfDay? afternoonTime,
    TimeOfDay? eveningTime,
  }) {
    return RitualWindowPreferences(
      morningTime: morningTime ?? this.morningTime,
      afternoonTime: afternoonTime ?? this.afternoonTime,
      eveningTime: eveningTime ?? this.eveningTime,
    );
  }

  /// Reset to default times
  static RitualWindowPreferences get defaults =>
      const RitualWindowPreferences();
}
