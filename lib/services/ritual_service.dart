import '../models/ritual.dart';

/// Service for managing rituals
/// Currently uses local state - ready for Firestore integration
/// 
/// To connect to Firestore:
/// 1. Run: flutterfire configure
/// 2. Add firebase_core and cloud_firestore to pubspec.yaml
/// 3. Initialize Firebase in main.dart
/// 4. Replace mock methods with Firestore queries
class RitualService {
  // Singleton pattern for easy access
  static final RitualService _instance = RitualService._internal();
  factory RitualService() => _instance;
  RitualService._internal();

  // Default rituals for new users
  List<Ritual> getDefaultRituals() {
    return const [
      Ritual(id: '1', name: 'Morning Breath', emoji: '🌅', streak: 0),
      Ritual(id: '2', name: 'Hydrate', emoji: '💧', streak: 0),
      Ritual(id: '3', name: 'Gratitude', emoji: '🙏', streak: 0),
      Ritual(id: '4', name: 'Move', emoji: '🚶', streak: 0),
    ];
  }

  // TODO: Replace with Firestore implementation
  // Future<List<Ritual>> fetchRituals(String userId) async {
  //   final snapshot = await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(userId)
  //       .collection('rituals')
  //       .get();
  //   return snapshot.docs.map((doc) => Ritual.fromJson(doc.data())).toList();
  // }

  // TODO: Replace with Firestore implementation
  // Future<void> updateRitual(String userId, Ritual ritual) async {
  //   await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(userId)
  //       .collection('rituals')
  //       .doc(ritual.id)
  //       .set(ritual.toJson());
  // }
}
