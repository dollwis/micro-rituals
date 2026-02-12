import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/meditation.dart';

// import '../models/notification_types.dart'; // No need to import if we use 'var' or explicit type from service return, but let's be safe
import 'package:flutter/material.dart';

/// Ritual Window Service
/// Manages 3 daily windows: Morning, Afternoon, Evening.
/// Windows are defined by user notification preferences.
/// One active window at a time. strict flow: Morning -> Afternoon -> Evening.
class RitualWindowService {
  // Window Constants
  static const int MORNING_WINDOW_INDEX = 0;
  static const int AFTERNOON_WINDOW_INDEX = 1;
  static const int EVENING_WINDOW_INDEX = 2;
  static const int TOTAL_WINDOWS = 3;

  // Window labels
  static const Map<int, String> windowLabels = {
    MORNING_WINDOW_INDEX: 'Morning Ritual',
    AFTERNOON_WINDOW_INDEX: 'Afternoon Reset',
    EVENING_WINDOW_INDEX: 'Evening Wind-Down',
  };

  // Categories appropriate for each window
  // Categories appropriate for each window
  static const Map<int, List<String>> windowCategories = {
    MORNING_WINDOW_INDEX: ['Morning', 'Focus', 'Breathing'],
    AFTERNOON_WINDOW_INDEX: ['Stress', 'Anxiety', 'Focus'],
    EVENING_WINDOW_INDEX: ['Sleep', 'Evening', 'Breathing'],
  };

  /// Get the current active window index based on user preferences.
  /// Returns -1 if no window is currently active (waiting period).
  static Future<int> getCurrentWindowIndex({DateTime? overrideTime}) async {
    final now = overrideTime ?? DateTime.now();
    return _calculateCurrentWindowIndex(now);
  }

  /// Synchronous helper for window calculation
  static int _calculateCurrentWindowIndex(DateTime now) {
    // Current time in minutes from midnight
    final nowMinutes = now.hour * 60 + now.minute;

    // Fixed Window Start Times (Decoupled from Notification Settings)
    // Morning: 04:00 - 12:00
    // Afternoon: 12:00 - 18:00
    // Evening: 18:00 - 04:00 (+1 day)

    const morningStart = 4 * 60; // 04:00
    const afternoonStart = 12 * 60; // 12:00
    const eveningStart = 18 * 60; // 18:00

    // Hardcoded End Times (to match NotificationService logic)
    // Morning Ends at 12:00
    const morningEnd = 12 * 60;
    // Afternoon Ends at 18:00
    const afternoonEnd = 18 * 60;
    // Evening Ends at 04:00 (Next Day) - handled by < 4 check below

    // Special Case: Early morning hours (00:00 - 04:00) count as previous day's Evening
    if (now.hour < 4) {
      return EVENING_WINDOW_INDEX;
    }

    // Morning Window
    if (nowMinutes >= morningStart && nowMinutes < morningEnd) {
      return MORNING_WINDOW_INDEX;
    }

    // Afternoon Window
    if (nowMinutes >= afternoonStart && nowMinutes < afternoonEnd) {
      return AFTERNOON_WINDOW_INDEX;
    }

    // Evening Window (From Evening Start -> Midnight)
    // Note: The 00:00->04:00 part is handled by the early check above.
    if (nowMinutes >= eveningStart) {
      return EVENING_WINDOW_INDEX;
    }

    return -1; // Waiting period
  }

  /// Get the start time of the NEXT window.
  static Future<DateTime> getNextWindowStartTime({
    DateTime? overrideTime,
  }) async {
    final now = overrideTime ?? DateTime.now();

    // Fixed start times
    const morningTime = TimeOfDay(hour: 4, minute: 0);
    const afternoonTime = TimeOfDay(hour: 12, minute: 0);
    const eveningTime = TimeOfDay(hour: 18, minute: 0);

    // Candidates for next start time
    final candidates = [
      _toDateTime(now, morningTime),
      _toDateTime(now, afternoonTime),
      _toDateTime(now, eveningTime),
      _toDateTime(now.add(const Duration(days: 1)), morningTime),
    ];

    // Find the first candidate strictly in the future
    for (final candidate in candidates) {
      if (candidate.isAfter(now)) {
        return candidate;
      }
    }

    // Fallback (should cover all cases, but just in case)
    return candidates.last;
  }

  static DateTime _toDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Get the start time of the NEXT *ACTIVE* window.
  /// Skips windows that are already completed for the day.
  /// This ensures sequential flow and prevents re-opening completed windows.
  static Future<DateTime> getNextActiveWindowStartTime({
    DateTime? overrideTime,
  }) async {
    final now = overrideTime ?? DateTime.now();

    var nextStart = now;

    // Fixed start times
    const morningTime = TimeOfDay(hour: 4, minute: 0);
    const afternoonTime = TimeOfDay(hour: 12, minute: 0);
    const eveningTime = TimeOfDay(hour: 18, minute: 0);

    // Safety break
    for (int i = 0; i < 5; i++) {
      // Find next scheduled start after 'nextStart'
      final candidates = [
        _toDateTime(nextStart, morningTime),
        _toDateTime(nextStart, afternoonTime),
        _toDateTime(nextStart, eveningTime),
        _toDateTime(nextStart.add(const Duration(days: 1)), morningTime),
        _toDateTime(
          nextStart.add(const Duration(days: 1)),
          afternoonTime,
        ), // Look further ahead
      ];

      DateTime? target;
      for (final c in candidates) {
        if (c.isAfter(nextStart)) {
          target = c;
          break;
        }
      }
      target ??= candidates.last;

      nextStart = target;

      // Identify which window index this start time belongs to
      final index = _getWindowIndexFromTime(nextStart);

      // Check completion
      final key = await _getWindowCompletionKey(index, nextStart);
      final sp = await SharedPreferences.getInstance();
      final isCompleted = sp.getBool(key) ?? false;

      if (!isCompleted) {
        return nextStart;
      }
    }

    return nextStart;
  }

  // Helper to identify window index from a specific start time
  static int _getWindowIndexFromTime(DateTime time) {
    final min = time.hour * 60 + time.minute;

    // Fixed start times in minutes
    const m = 4 * 60; // 04:00
    const a = 12 * 60; // 12:00
    const e = 18 * 60; // 18:00

    if (min == m) return MORNING_WINDOW_INDEX;
    if (min == a) return AFTERNOON_WINDOW_INDEX;
    if (min == e) return EVENING_WINDOW_INDEX;

    return MORNING_WINDOW_INDEX;
  }

  /// Calculate time remaining until the next ACTIVE window opens.
  static Future<Duration> getTimeUntilNextWindow({
    DateTime? overrideTime,
  }) async {
    final now = overrideTime ?? DateTime.now();
    final nextStart = await getNextActiveWindowStartTime(overrideTime: now);
    return nextStart.difference(now);
  }

  // Alias for backward compatibility if needed, generic name
  static Future<Duration> getTimeUntilNextNotificationWindow({
    DateTime? overrideTime,
  }) async {
    return getTimeUntilNextWindow(overrideTime: overrideTime);
  }

  // ============ FORMATTING ============

  static String formatCountdown(Duration duration) {
    if (duration.isNegative) return '00:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  static String formatCountdownWithSeconds(Duration duration) {
    if (duration.isNegative) return '00:00:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ============ MEDITATION CACHING & SELECTION ============

  static List<Meditation>? _cachedMeditations;

  static void cacheMeditations(List<Meditation> meditations) {
    _cachedMeditations = meditations;
  }

  /// Get the ritual for the current active window.
  /// Returns NULL if no window is active (waiting mode) or if caches empty.
  static Future<Meditation?> getCurrentWindowRitual({
    DateTime? overrideTime,
  }) async {
    final index = await getCurrentWindowIndex(overrideTime: overrideTime);
    if (index == -1) return null; // Waiting period

    return getRitualForWindow(index, date: overrideTime);
  }

  /// Get the ritual for the NEXT window (used when waiting).
  static Future<Meditation?> getNextWindowRitual({
    DateTime? overrideTime,
  }) async {
    final nextStart = await getNextActiveWindowStartTime(
      overrideTime: overrideTime,
    );
    final index = _getWindowIndexFromTime(nextStart);
    return getRitualForWindow(index, date: nextStart);
  }

  static Meditation? getRitualForWindow(int windowIndex, {DateTime? date}) {
    if (_cachedMeditations == null || _cachedMeditations!.isEmpty) {
      return null;
    }

    // Explicit safety check
    if (!windowCategories.containsKey(windowIndex)) return null;

    final d = date ?? DateTime.now();
    final appropriateCategories = windowCategories[windowIndex]!;

    final eligibleRituals = _cachedMeditations!
        .where((r) => appropriateCategories.contains(r.category))
        .toList();

    final ritualsToChooseFrom = eligibleRituals.isNotEmpty
        ? eligibleRituals
        : _cachedMeditations!;

    // Deterministic seed: Date + WindowIndex
    // This ensures that if the user opens the app multiple times during the same window, they see the same ritual.
    final seed =
        d.year * 10000 + d.month * 100 + d.day + (windowIndex + 1) * 1000000;
    final random = Random(seed);

    return ritualsToChooseFrom[random.nextInt(ritualsToChooseFrom.length)];
  }

  /// Get label for display
  static Future<String> getCurrentWindowLabel({DateTime? overrideTime}) async {
    final index = await getCurrentWindowIndex(overrideTime: overrideTime);
    return windowLabels[index] ?? 'Daily Ritual';
  }

  /// Get label for the NEXT window
  static Future<String> getNextWindowLabel({DateTime? overrideTime}) async {
    final start = await getNextActiveWindowStartTime(
      overrideTime: overrideTime,
    );
    final index = _getWindowIndexFromTime(start);
    return windowLabels[index] ?? 'Next Ritual';
  }

  // ============ COMPLETION TRACKING ============

  /// Key format: 'window_completed_YYYY_MM_DD_INDEX'
  static Future<String> _getWindowCompletionKey(
    int windowIndex,
    DateTime time,
  ) async {
    return 'window_completed_${time.year}_${time.month}_${time.day}_$windowIndex';
  }

  /// Check if the currently active window is completed.
  static Future<bool> isCurrentWindowCompleted({DateTime? overrideTime}) async {
    final index = await getCurrentWindowIndex(overrideTime: overrideTime);
    // Even if index is active, we check if it is marked as done.
    if (index == -1) return false;

    final time = overrideTime ?? DateTime.now();
    var dateForKey = time;
    if (index == EVENING_WINDOW_INDEX && time.hour < 4) {
      dateForKey = time.subtract(const Duration(days: 1));
    }

    final key = await _getWindowCompletionKey(index, dateForKey);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  /// Mark the current window as completed.
  /// Also ensures we LOCK this window for the day.
  static Future<void> markCurrentWindowCompleted({
    DateTime? overrideTime,
  }) async {
    final index = await getCurrentWindowIndex(overrideTime: overrideTime);
    if (index == -1) return;

    final time = overrideTime ?? DateTime.now();
    var dateForKey = time;
    if (index == EVENING_WINDOW_INDEX && time.hour < 4) {
      dateForKey = time.subtract(const Duration(days: 1));
    }

    final key = await _getWindowCompletionKey(index, dateForKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  /// Get the status of all 3 windows for a specific date.
  /// Returns a Map<int, String> where key is window index and value is status:
  /// 'completed', 'active', 'missed', 'upcoming'
  static Future<Map<int, String>> getDailyWindowStatuses(DateTime date) async {
    final statuses = <int, String>{};

    // Calculate current time context
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    for (int i = 0; i < TOTAL_WINDOWS; i++) {
      // 1. Check if completed
      // For evening window, if checking "today", we might need to check late night hours
      // But usually we key completion by the "logical" day.
      // The _getWindowCompletionKey uses the passed date.
      final key = await _getWindowCompletionKey(i, date);
      final sp = await SharedPreferences.getInstance();
      final isCompleted = sp.getBool(key) ?? false;

      if (isCompleted) {
        statuses[i] = 'completed';
        continue;
      }

      // If not completed, check if it's active, passed (missed), or upcoming
      if (!isToday) {
        // If checking a past date, and not completed -> Missed
        if (date.isBefore(DateTime(now.year, now.month, now.day))) {
          statuses[i] = 'missed';
        } else {
          // Future date -> Upcoming
          statuses[i] = 'upcoming';
        }
        continue;
      }

      // It is Today
      final currentIndex = await getCurrentWindowIndex();

      if (i == currentIndex) {
        statuses[i] = 'active';
      } else if (i < currentIndex ||
          (currentIndex == -1 && _hasWindowPassed(i, now))) {
        // If the window index is less than current (previous windows)
        // OR it's a waiting period (-1) but this window has passed
        statuses[i] = 'missed';
      } else {
        statuses[i] = 'upcoming';
      }
    }

    return statuses;
  }

  static bool _hasWindowPassed(int windowIndex, DateTime now) {
    final nowMinutes = now.hour * 60 + now.minute;

    // Define end times (same as in _calculateCurrentWindowIndex)
    const morningEnd = 12 * 60;
    const afternoonEnd = 18 * 60;
    // Evening "end" is technically 4 AM next day, so for "today's" evening it hasn't passed until tomorrow

    if (windowIndex == MORNING_WINDOW_INDEX) {
      return nowMinutes >= morningEnd;
    } else if (windowIndex == AFTERNOON_WINDOW_INDEX) {
      return nowMinutes >= afternoonEnd;
    }

    // Evening window basically never "passes" within the same calendar day because it extends to next day
    return false;
  }
}
