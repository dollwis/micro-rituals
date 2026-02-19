import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/firestore_user.dart';
import '../models/activity_record.dart';
import './firestore_service.dart';

/// Service for local storage of user stats and offline activity tracking
class LocalStatsService {
  static final LocalStatsService _instance = LocalStatsService._internal();
  factory LocalStatsService() => _instance;
  LocalStatsService._internal();

  static const String _userStatsKey = 'local_user_stats';
  static const String _activitiesKey = 'pending_activities';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // ══════════════════════════════════════════════════════════════════════════
  // User Stats Storage
  // ══════════════════════════════════════════════════════════════════════════

  /// Save user stats to local storage
  Future<void> saveLocalStats(FirestoreUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final json = user.toJson();

    // Convert Timestamps to ISO strings for local storage
    final localJson = _convertTimestampsToStrings(json);
    await prefs.setString(_userStatsKey, jsonEncode(localJson));
  }

  /// Load user stats from local storage
  Future<FirestoreUser?> getLocalStats(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userStatsKey);

    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final firestoreJson = _convertStringsToTimestamps(json);
      return FirestoreUser.fromJson(firestoreJson);
    } catch (e) {
      debugPrint('Error loading local stats: $e');
      return null;
    }
  }

  /// Clear local stats
  Future<void> clearLocalStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userStatsKey);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Activity Tracking
  // ══════════════════════════════════════════════════════════════════════════

  /// Track an activity while offline
  Future<void> trackOfflineActivity(ActivityRecord activity) async {
    final prefs = await SharedPreferences.getInstance();
    final activities = await getPendingSyncActivities();

    activities.add(activity);

    final jsonList = activities.map((a) => a.toJson()).toList();
    await prefs.setString(_activitiesKey, jsonEncode(jsonList));
  }

  /// Get all pending activities that need to be synced
  Future<List<ActivityRecord>> getPendingSyncActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_activitiesKey);

    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => ActivityRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading pending activities: $e');
      return [];
    }
  }

  /// Mark an activity as synced
  Future<void> markActivitySynced(String activityId) async {
    final activities = await getPendingSyncActivities();
    final updated = activities
        .map((a) => a.id == activityId ? a.copyWith(synced: true) : a)
        .toList();

    final prefs = await SharedPreferences.getInstance();
    final jsonList = updated.map((a) => a.toJson()).toList();
    await prefs.setString(_activitiesKey, jsonEncode(jsonList));
  }

  /// Remove synced activities
  Future<void> removeSyncedActivities() async {
    final activities = await getPendingSyncActivities();
    final pending = activities.where((a) => !a.synced).toList();

    final prefs = await SharedPreferences.getInstance();
    final jsonList = pending.map((a) => a.toJson()).toList();
    await prefs.setString(_activitiesKey, jsonEncode(jsonList));
  }

  /// Get count of pending activities
  Future<int> getPendingCount() async {
    final activities = await getPendingSyncActivities();
    return activities.where((a) => !a.synced).length;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Sync Operations
  // ══════════════════════════════════════════════════════════════════════════

  /// Sync local activities to Firestore
  Future<void> syncWithFirestore(String userId) async {
    final activities = await getPendingSyncActivities();
    final pending = activities.where((a) => !a.synced).toList();

    if (pending.isEmpty) return;

    final firestoreService = FirestoreService();

    for (final activity in pending) {
      try {
        // Log ritual minutes in Firestore
        await firestoreService.logRitualMinutes(
          activity.userId,
          (activity.durationSeconds / 60).ceil(),
          seconds: activity.durationSeconds,
          ritualName: 'Meditation', // Generic name for now
          source: 'offline_sync',
        );

        // Mark complete if it was a completed session
        if (activity.completed) {
          await firestoreService.markRitualComplete(activity.userId);
        }

        // Mark as synced
        await markActivitySynced(activity.id);
      } catch (e) {
        debugPrint('Error syncing activity ${activity.id}: $e');
        // Continue with other activities
      }
    }

    // Clean up synced activities
    await removeSyncedActivities();

    // Update last sync timestamp
    await _updateLastSyncTime();
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastSyncKey);
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Merge & Conflict Resolution
  // ══════════════════════════════════════════════════════════════════════════

  /// Merge online and local stats (for conflict resolution)
  FirestoreUser mergeStats(FirestoreUser online, FirestoreUser local) {
    return online.copyWith(
      // Use max values for counters
      totalCompleted: max(online.totalCompleted, local.totalCompleted),
      totalMinutes: max(online.totalMinutes, local.totalMinutes),
      minutesThisWeek: max(online.minutesThisWeek, local.minutesThisWeek),

      // Server is source of truth for streak
      currentStreak: online.currentStreak,

      // Merge lists (union)
      favoriteIds: {...online.favoriteIds, ...local.favoriteIds}.toList(),
      listenLaterIds: {
        ...online.listenLaterIds,
        ...local.listenLaterIds,
      }.toList(),

      // Use latest timestamp
      lastCompletionDate:
          online.lastCompletionDate != null && local.lastCompletionDate != null
          ? (online.lastCompletionDate!.isAfter(local.lastCompletionDate!)
                ? online.lastCompletionDate
                : local.lastCompletionDate)
          : online.lastCompletionDate ?? local.lastCompletionDate,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Helper Methods
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _convertTimestampsToStrings(Map<String, dynamic> json) {
    final result = Map<String, dynamic>.from(json);
    final timestampKeys = [
      'last_completion_date',
      'created_at',
      'subscription_expiry',
      'last_weekly_reset',
    ];

    for (final key in timestampKeys) {
      if (result[key] != null) {
        // If it's a Timestamp, convert to DateTime then to string
        final value = result[key];
        if (value is String) {
          continue; // Already a string
        } else {
          try {
            final dateTime = (value as dynamic).toDate() as DateTime;
            result[key] = dateTime.toIso8601String();
          } catch (e) {
            result[key] = null;
          }
        }
      }
    }

    return result;
  }

  Map<String, dynamic> _convertStringsToTimestamps(Map<String, dynamic> json) {
    final result = Map<String, dynamic>.from(json);
    final timestampKeys = [
      'last_completion_date',
      'created_at',
      'subscription_expiry',
      'last_weekly_reset',
    ];

    for (final key in timestampKeys) {
      if (result[key] != null && result[key] is String) {
        try {
          final dateTime = DateTime.parse(result[key] as String);
          // Keep as DateTime for FirestoreUser.fromJson to handle
          result[key] = dateTime;
        } catch (e) {
          result[key] = null;
        }
      }
    }

    return result;
  }
}
