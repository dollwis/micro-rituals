import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firestore_user.dart';

class LocalUserService {
  static final LocalUserService _instance = LocalUserService._internal();
  factory LocalUserService() => _instance;
  LocalUserService._internal();

  static const String _userKey = 'guest_user_data';
  static const String _historyKey = 'guest_user_history';

  final _userStreamController = StreamController<FirestoreUser?>.broadcast();
  Stream<FirestoreUser?> get userStream => _userStreamController.stream;

  final _historyStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get historyStream =>
      _historyStreamController.stream;

  /// Get current local user or create one if not exists
  Future<FirestoreUser> getOrCreateUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userKey);

    if (jsonString != null) {
      try {
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        final firestoreMap = _localMapToFirestoreMap(jsonMap);
        final user = FirestoreUser.fromJson(firestoreMap);
        // Push to stream
        _userStreamController.add(user);
        return user;
      } catch (e) {
        print('Error parsing local user: $e');
      }
    }

    // Create new
    final now = DateTime.now();
    final newUser = FirestoreUser(
      uid: uid,
      createdAt: now,
      lastWeeklyReset: now,
      username: 'Guest',
    );

    await saveUser(newUser);
    return newUser;
  }

  Future<void> saveUser(FirestoreUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(_userToLocalMap(user)));
    _userStreamController.add(user);
  }

  /// Update user with a modifier function
  Future<void> updateUser(
    String uid,
    FirestoreUser Function(FirestoreUser) updateFn,
  ) async {
    final user = await getOrCreateUser(uid);
    final updatedUser = updateFn(user);
    await saveUser(updatedUser);
  }

  // --- History / Completions ---

  Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_historyKey);
    if (jsonString != null) {
      try {
        final List<dynamic> list = jsonDecode(jsonString);
        final history = list.cast<Map<String, dynamic>>();
        _historyStreamController.add(history);
        return history;
      } catch (e) {
        print('Error parsing local history: $e');
      }
    }
    return [];
  }

  Future<void> addHistoryEntry(Map<String, dynamic> entry) async {
    final history = await getHistory();
    // Add new entry
    final newEntry = Map<String, dynamic>.from(entry);
    if (!newEntry.containsKey('id')) {
      newEntry['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    }

    // Sort descending by completed_at if possible (but we usually just prepend/append)
    // For specific sorting we can do it on read.
    // Let's prepend for "recent first"
    history.insert(0, newEntry);

    await _saveHistory(history);
  }

  Future<void> updateHistoryEntry(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final history = await getHistory();
    final index = history.indexWhere((e) => e['id'] == id);
    if (index != -1) {
      history[index] = {...history[index], ...updates};
      await _saveHistory(history);
    }
  }

  Future<void> deleteHistoryEntry(String id) async {
    final history = await getHistory();
    history.removeWhere((e) => e['id'] == id);
    await _saveHistory(history);
  }

  Future<void> _saveHistory(List<Map<String, dynamic>> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(history));
    _historyStreamController.add(history);
  }

  // --- Helpers for Serialization ---

  Map<String, dynamic> _userToLocalMap(FirestoreUser user) {
    final map = user.toJson();
    final keys = [
      'last_completion_date',
      'created_at',
      'subscription_expiry',
      'last_weekly_reset',
    ];
    for (var key in keys) {
      if (map[key] is Timestamp) {
        map[key] = (map[key] as Timestamp).toDate().toIso8601String();
      }
    }
    return map;
  }

  Map<String, dynamic> _localMapToFirestoreMap(Map<String, dynamic> json) {
    final keys = [
      'last_completion_date',
      'created_at',
      'subscription_expiry',
      'last_weekly_reset',
    ];
    for (var key in keys) {
      if (json[key] is String) {
        json[key] = Timestamp.fromDate(DateTime.parse(json[key]));
      }
    }
    return json;
  }
}
