import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meditation.dart';

/// Ritual Window Service
/// Divides the 24-hour day into 6 windows and selects time-appropriate rituals
///
/// Window Schedule:
/// - Window 0 (00:00-04:00): Night/Sleep - Relaxing breath work
/// - Window 1 (04:00-08:00): Early Morning - Energizing stretches
/// - Window 2 (08:00-12:00): Morning - Focus/productivity rituals
/// - Window 3 (12:00-16:00): Afternoon - Re-energizing stretches
/// - Window 4 (16:00-20:00): Evening - Wind-down focus rituals
/// - Window 5 (20:00-00:00): Night - Relaxing breath work
class RitualWindowService {
  static const int windowDurationHours = 4;
  static const int totalWindows = 6;

  // Define which categories are appropriate for each window
  static const Map<int, List<String>> windowCategories = {
    0: ['Sleep', 'Breathing'], // Night: Calm breathing
    1: ['Morning', 'Breathing'], // Early Morning: Wake-up stretches
    2: ['Focus'], // Morning: Focus & productivity
    3: ['Stress', 'Anxiety'], // Afternoon: Re-energize
    4: ['Evening', 'Focus'], // Evening: Wind down
    5: ['Sleep'], // Night: Relaxation
  };

  // Window labels for UI display
  static const Map<int, String> windowLabels = {
    0: 'Night Calm',
    1: 'Morning Stretch',
    2: 'Focus Hour',
    3: 'Afternoon Reset',
    4: 'Evening Wind-Down',
    5: 'Sleep Prep',
  };

  /// Get the current window index (0-5) based on the hour
  static int getCurrentWindowIndex({DateTime? overrideTime}) {
    final now = overrideTime ?? DateTime.now();
    return now.hour ~/ windowDurationHours;
  }

  /// Get the start time of a specific window for today
  static DateTime getWindowStartTime(
    int windowIndex, {
    DateTime? overrideDate,
  }) {
    final date = overrideDate ?? DateTime.now();
    final hour = windowIndex * windowDurationHours;
    return DateTime(date.year, date.month, date.day, hour, 0, 0);
  }

  /// Get the start time of the next window
  static DateTime getNextWindowStartTime({DateTime? overrideTime}) {
    final now = overrideTime ?? DateTime.now();
    final currentWindow = getCurrentWindowIndex(overrideTime: now);

    if (currentWindow == totalWindows - 1) {
      // Next window is tomorrow at 00:00
      return DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    }

    return getWindowStartTime(currentWindow + 1, overrideDate: now);
  }

  /// Get the duration until the next window opens
  static Duration getTimeUntilNextWindow({DateTime? overrideTime}) {
    final now = overrideTime ?? DateTime.now();
    final nextStart = getNextWindowStartTime(overrideTime: now);
    return nextStart.difference(now);
  }

  /// Format duration as "HH:MM"
  static String formatCountdown(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Format duration as "H:MM:SS" for more precise display
  static String formatCountdownWithSeconds(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Cached list to avoid frequent fetches (could be improved with a provider)
  static List<Meditation>? _cachedMeditations;

  /// Set the cache of meditations (called usually from Dashboard)
  static void cacheMeditations(List<Meditation> meditations) {
    _cachedMeditations = meditations;
  }

  /// Get the ritual for the current window
  /// Selects from time-appropriate categories using date+window as seed
  static Meditation? getCurrentWindowRitual({DateTime? overrideTime}) {
    final time = overrideTime ?? DateTime.now();
    final windowIndex = getCurrentWindowIndex(overrideTime: time);
    return getRitualForWindow(windowIndex, date: time);
  }

  /// Get the ritual for a specific window
  /// Uses deterministic selection based on date + window for consistency
  static Meditation? getRitualForWindow(int windowIndex, {DateTime? date}) {
    if (_cachedMeditations == null || _cachedMeditations!.isEmpty) {
      return null;
    }

    final d = date ?? DateTime.now();

    // Get appropriate categories for this window
    final appropriateCategories = windowCategories[windowIndex] ?? ['Focus'];

    // Filter rituals by appropriate categories
    final eligibleRituals = _cachedMeditations!
        .where((r) => appropriateCategories.contains(r.category))
        .toList();

    // Fallback to all rituals if no matches
    final ritualsToChooseFrom = eligibleRituals.isNotEmpty
        ? eligibleRituals
        : _cachedMeditations!;

    // Create deterministic seed from date + window
    final seed = d.year * 10000 + d.month * 100 + d.day + windowIndex * 1000000;
    final random = Random(seed);

    return ritualsToChooseFrom[random.nextInt(ritualsToChooseFrom.length)];
  }

  /// Get the label for the current window
  static String getCurrentWindowLabel({DateTime? overrideTime}) {
    final windowIndex = getCurrentWindowIndex(overrideTime: overrideTime);
    return windowLabels[windowIndex] ?? 'Ritual Time';
  }

  // ============ COMPLETION TRACKING ============

  /// Get the unique key for storing current window completion
  static String _getWindowCompletionKey(DateTime time) {
    final windowIndex = getCurrentWindowIndex(overrideTime: time);
    return 'window_completed_${time.year}_${time.month}_${time.day}_$windowIndex';
  }

  /// Check if the current window's ritual has been completed
  static Future<bool> isCurrentWindowCompleted({DateTime? overrideTime}) async {
    final time = overrideTime ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final key = _getWindowCompletionKey(time);
    return prefs.getBool(key) ?? false;
  }

  /// Mark the current window as completed
  static Future<void> markCurrentWindowCompleted({
    DateTime? overrideTime,
  }) async {
    final time = overrideTime ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final key = _getWindowCompletionKey(time);
    await prefs.setBool(key, true);
  }

  /// Clear completion status (for testing)
  static Future<void> clearCurrentWindowCompletion({
    DateTime? overrideTime,
  }) async {
    final time = overrideTime ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final key = _getWindowCompletionKey(time);
    await prefs.remove(key);
  }
}
