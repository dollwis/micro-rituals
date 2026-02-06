import '../models/firestore_ritual.dart';

/// Seed data for the 'rituals' Firestore collection
/// These 5 sample rituals can be used to populate an empty database
class RitualSeedData {
  static const List<FirestoreRitual> seedRituals = [];

  /// Get all seed rituals
  static List<FirestoreRitual> getAll() => seedRituals;

  /// Get rituals by category
  static List<FirestoreRitual> getByCategory(RitualCategory category) {
    return seedRituals.where((r) => r.category == category).toList();
  }
}
