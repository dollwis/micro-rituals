import 'dart:math';
import '../models/firestore_ritual.dart';
import '../data/ritual_seed_data.dart';

/// Deterministic "Ritual of the Day" selector
/// Uses the calendar date (YYYY-MM-DD) as a seed for pseudo-random selection
/// Ensures all users see the same ritual each day for community cohesion
class RitualOfTheDayService {
  /// Get today's ritual using date-seeded randomization
  /// All users will see the same ritual for any given date
  /// Get today's ritual using date-seeded randomization
  /// All users will see the same ritual for any given date
  static FirestoreRitual? getRitualOfTheDay({DateTime? overrideDate}) {
    final date = overrideDate ?? DateTime.now();
    final rituals = RitualSeedData.getAll();

    if (rituals.isEmpty) return null;

    final index = _getDateSeededIndex(date, rituals.length);
    return rituals[index];
  }

  /// Generate a deterministic index based on the date
  /// Uses YYYY-MM-DD format as seed for consistency across timezones
  static int _getDateSeededIndex(DateTime date, int maxIndex) {
    if (maxIndex <= 0) return 0;

    // Create seed from date components: YYYYMMDD as integer
    final seed = date.year * 10000 + date.month * 100 + date.day;

    // Use Random with fixed seed for deterministic output
    final random = Random(seed);

    return random.nextInt(maxIndex);
  }

  /// Get the seed value for a given date (for debugging/verification)
  static int getDateSeed({DateTime? date}) {
    final d = date ?? DateTime.now();
    return d.year * 10000 + d.month * 100 + d.day;
  }

  /// Check if a ritual is today's ritual
  static bool? isTodaysRitual(FirestoreRitual ritual) {
    final todayRitual = getRitualOfTheDay();
    if (todayRitual == null) return null;
    return ritual.id == todayRitual.id;
  }

  /// Get ritual of the day from a custom list (for Firestore data)
  static FirestoreRitual? getRitualOfTheDayFromList(
    List<FirestoreRitual> rituals, {
    DateTime? overrideDate,
  }) {
    if (rituals.isEmpty) {
      // Fallback to seed data if list is empty
      return getRitualOfTheDay(overrideDate: overrideDate);
    }

    final date = overrideDate ?? DateTime.now();
    final index = _getDateSeededIndex(date, rituals.length);
    return rituals[index];
  }
}
