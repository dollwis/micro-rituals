import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meditation.dart';
import '../models/firestore_user.dart';
import 'local_user_service.dart';

class ActivityData {
  final int totalMinutes;
  final int sessionCount;
  final int ritualWindowCount; // Count of 'ritual_window' sessions
  final List<String> ritualNames;

  const ActivityData({
    required this.totalMinutes,
    required this.sessionCount,
    this.ritualWindowCount = 0,
    required this.ritualNames,
  });

  /// Add another completion to this day's data
  ActivityData addCompletion(int minutes, String ritualName, {String? source}) {
    return ActivityData(
      totalMinutes: totalMinutes + minutes,
      sessionCount: sessionCount + 1,
      ritualWindowCount:
          ritualWindowCount + (source == 'ritual_window' ? 1 : 0),
      ritualNames: [...ritualNames, ritualName],
    );
  }

  /// Get intensity level (0-3) based on total minutes
  /// 0: no activity, 1: light (1-5 min), 2: medium (6-30 min), 3: strong (30+ min)
  int get intensityLevel {
    if (totalMinutes == 0) return 0;
    if (totalMinutes <= 15) return 1;
    if (totalMinutes <= 60) return 2;
    return 3;
  }
}

/// Firestore service for Daily MicroRituals
/// Handles CRUD operations for 'rituals' and 'users' collections
class FirestoreService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final LocalUserService _localUserService = LocalUserService();

  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  bool get _isGuest => _auth.currentUser?.isAnonymous ?? false;

  // Collection references

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // ============ USERS COLLECTION ============

  /// Get today's date as YYYY-MM-DD string
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Check and reset weekly stats if needed
  FirestoreUser _checkWeeklyReset(FirestoreUser user) {
    final now = DateTime.now();
    // Simple reset logic: every Monday
    // Calculate start of current week (Monday)
    final currentWeekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final lastWeekStart = user.lastWeeklyReset != null
        ? DateTime(
            user.lastWeeklyReset!.year,
            user.lastWeeklyReset!.month,
            user.lastWeeklyReset!.day,
          ).subtract(Duration(days: user.lastWeeklyReset!.weekday - 1))
        : null;

    // If it's a new week (different Monday than stored)
    if (lastWeekStart == null ||
        !currentWeekStart.isAtSameMomentAs(lastWeekStart)) {
      // New week!
      // Current "this week" becomes "last week"
      // "This week" resets to 0
      return user.copyWith(
        minutesLastWeek: user.minutesThisWeek,
        minutesThisWeek: 0,
        lastWeeklyReset: now,
      );
    }
    return user;
  }

  /// Get or create user document
  Future<FirestoreUser> getOrCreateUser(String uid) async {
    if (_isGuest) {
      // Local Guest Logic
      var user = await _localUserService.getOrCreateUser(uid);

      // Reset checks
      final today = _getTodayString();
      if (user.lastCompletionDay != today) {
        user = user.copyWith(completedToday: 0);
      }
      user = _checkWeeklyReset(user);

      // Save changes if any
      await _localUserService.saveUser(user);
      return user;
    }

    // Firestore Logic
    final doc = await _usersCollection.doc(uid).get();

    if (doc.exists) {
      var user = FirestoreUser.fromJson(doc.data()!);

      // Reset completedToday if it's a new day
      final today = _getTodayString();
      if (user.lastCompletionDay != today) {
        user = user.copyWith(completedToday: 0);
      }

      // Check weekly reset
      final updatedUser = _checkWeeklyReset(user);
      if (updatedUser != user) {
        // Save the reset if logic triggered
        await _usersCollection.doc(uid).update(updatedUser.toJson());
        return updatedUser;
      }

      return user;
    }

    // Create new user with created_at timestamp
    final now = DateTime.now();
    final newUser = FirestoreUser(
      uid: uid,
      createdAt: now,
      lastWeeklyReset: now, // Initialize reset date
    );
    await _usersCollection.doc(uid).set(newUser.toJson());
    return newUser;
  }

  /// Update user stats after completing a ritual
  /// Log minutes listened to a ritual, updating history and total stats
  Future<void> logRitualMinutes(
    String uid,
    int minutes, {
    int? seconds,
    String ritualName = 'Ritual',
    String? coverImageUrl,
    String? source, // 'ritual_window', 'library', etc.
  }) async {
    if (minutes <= 0 && (seconds == null || seconds <= 0)) return;
    await getOrCreateUser(uid); // Ensure exists

    final now = DateTime.now();

    if (_isGuest) {
      // Local Guest Logic
      await _localUserService.updateUser(uid, (user) {
        return user.copyWith(
          totalMinutes: user.totalMinutes + minutes,
          minutesThisWeek: user.minutesThisWeek + minutes,
          lastCompletionDate: now,
        );
      });

      // History (Aggregation Logic for Local)
      final history = await _localUserService.getHistory();
      final todayStart = DateTime(now.year, now.month, now.day);

      final todayIndex = history.indexWhere((entry) {
        // Check if same ritual and today
        final entryDate = DateTime.parse(
          entry['completed_at_iso'] ??
              DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
        );
        return entry['ritual_name'] == ritualName &&
            entryDate.isAfter(todayStart);
      });

      if (todayIndex != -1) {
        // Aggregate
        final existing = history[todayIndex];
        await _localUserService.updateHistoryEntry(existing['id'], {
          'duration_minutes': (existing['duration_minutes'] as int) + minutes,
          if (seconds != null)
            'duration_seconds':
                ((existing['duration_seconds'] as int?) ?? 0) + seconds,
          'completed_at_iso': now.toIso8601String(), // Use ISO for local
          'completed_at': now.millisecondsSinceEpoch, // For compatibility
          if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
          if (source != null) 'source': source,
        });
      } else {
        // Add new
        await _localUserService.addHistoryEntry({
          'ritual_name': ritualName,
          'duration_minutes': minutes,
          if (seconds != null) 'duration_seconds': seconds,
          'completed_at_iso': now.toIso8601String(),
          'completed_at': now.millisecondsSinceEpoch,
          if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
          if (source != null) 'source': source,
        });
      }

      return;
    }

    // Firestore Logic
    final todayStart = DateTime(now.year, now.month, now.day);

    // 1. Update User Stats (Global Minutes)
    await _usersCollection.doc(uid).update({
      'total_minutes': FieldValue.increment(minutes),
      'minutes_this_week': FieldValue.increment(minutes),
      'last_completion_date': Timestamp.fromDate(now),
    });

    // 2. Update or Create History Entry (Aggregation)
    final historyQuery = await _usersCollection
        .doc(uid)
        .collection('completions')
        .where('ritual_name', isEqualTo: ritualName)
        .where(
          'completed_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
        )
        .limit(1)
        .get();

    if (historyQuery.docs.isNotEmpty) {
      // Aggregate with existing entry for today
      await historyQuery.docs.first.reference.update({
        'duration_minutes': FieldValue.increment(minutes),
        if (seconds != null) 'duration_seconds': FieldValue.increment(seconds),
        'completed_at': Timestamp.fromDate(now),
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
        if (source != null) 'source': source,
      });
    } else {
      // Create new entry
      await _usersCollection.doc(uid).collection('completions').add({
        'ritual_name': ritualName,
        'duration_minutes': minutes,
        if (seconds != null) 'duration_seconds': seconds,
        'completed_at': Timestamp.fromDate(now),
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
        if (source != null) 'source': source,
      });
    }
  }

  /// Mark a ritual as "Completed" (for streak and session count)
  /// Should only be called when 50% threshold is met
  Future<void> markRitualComplete(String uid) async {
    var user = await getOrCreateUser(uid);
    final now = DateTime.now();
    final today = _getTodayString();

    // Streak Logic (Robust Date Comparison)
    int newStreak = user.currentStreak;
    int newCompletedToday = user.completedToday;

    // Normalize dates to midnight to compare days effectively
    final nowMidnight = DateTime(now.year, now.month, now.day);
    DateTime? lastMidnight;

    if (user.lastCompletionDay != null) {
      final parts = user.lastCompletionDay!.split('-');
      if (parts.length == 3) {
        lastMidnight = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    }

    if (lastMidnight != null && lastMidnight.isAtSameMomentAs(nowMidnight)) {
      // Already completed today
      newCompletedToday = user.completedToday + 1;
      // Streak stays same
    } else if (lastMidnight != null &&
        nowMidnight.difference(lastMidnight).inHours >=
            20 && // Tolerance for DST/Timezone shifts, checking ~1 day
        nowMidnight.difference(lastMidnight).inHours <= 28) {
      // Crude check? No, let's use days from midnight.

      // Better: subtract 1 day from nowMidnight and check equality
      final yesterdayMidnight = nowMidnight.subtract(const Duration(days: 1));

      if (lastMidnight.isAtSameMomentAs(yesterdayMidnight)) {
        // Completed yesterday
        newStreak++;
        newCompletedToday = 1;
      } else {
        // Missed a day
        newStreak = 1;
        newCompletedToday = 1;
      }
    } else {
      // Logic for difference > 1 day or first time
      // Let's refine the "yesterday" check above simpler:
      final yesterdayMidnight = nowMidnight.subtract(const Duration(days: 1));
      if (lastMidnight != null &&
          lastMidnight.isAtSameMomentAs(yesterdayMidnight)) {
        newStreak++;
        newCompletedToday = 1;
      } else {
        // Reset
        newStreak = 1;
        newCompletedToday = 1;
      }
    }

    if (_isGuest) {
      await _localUserService.updateUser(uid, (u) {
        return u.copyWith(
          currentStreak: newStreak,
          totalCompleted: u.totalCompleted + 1,
          completedToday: newCompletedToday,
          lastCompletionDate: now,
          lastCompletionDay: today,
        );
      });
      return;
    }

    // Update Firestore
    await _usersCollection.doc(uid).update({
      'current_streak': newStreak,
      'total_completed': FieldValue.increment(1),
      'completed_today': newCompletedToday,
      'last_completion_date': Timestamp.fromDate(now),
      'last_completion_day': today,
    });
  }

  /// Legacy method - keeping for compatibility but forwarding to new logic where possible
  /// or deprecating. For now, let's leave it but recommend using logRitualMinutes + markRitualComplete.
  Future<void> recordCompletion(
    String uid,
    int ritualDurationSeconds, {
    String ritualName = 'Ritual',
    String? coverImageUrl,
    bool updateStats = true,
    String? source,
  }) async {
    // Use new granular methods
    final minutes = (ritualDurationSeconds / 60).ceil();

    // 1. Log minutes (handles history)
    if (updateStats && minutes > 0) {
      await logRitualMinutes(
        uid,
        minutes,
        seconds: ritualDurationSeconds,
        ritualName: ritualName,
        coverImageUrl: coverImageUrl,
        source: source,
      );
    }

    // 2. Mark complete (handles streak/count)
    await markRitualComplete(uid);
  }

  /// Stream user's completion history (most recent first)
  Stream<List<Map<String, dynamic>>> streamCompletionHistory(
    String uid, {
    int limit = 10,
    DateTime? startDate,
  }) {
    if (_isGuest) {
      return _localUserService.historyStream.map((list) {
        var filteredList = list;
        if (startDate != null) {
          filteredList = list.where((e) {
            final date = DateTime.parse(
              e['completed_at_iso'] ??
                  DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
            );
            return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
          }).toList();
        }

        return filteredList
            .map((e) {
              final entry = Map<String, dynamic>.from(e);
              // Convert int to Timestamp for UI compatibility
              if (entry['completed_at'] is int) {
                entry['completed_at'] = Timestamp.fromMillisecondsSinceEpoch(
                  entry['completed_at'],
                );
              }
              return entry;
            })
            .take(limit)
            .toList();
      });
    }

    Query<Map<String, dynamic>> query = _usersCollection
        .doc(uid)
        .collection('completions')
        .orderBy('completed_at', descending: true);

    if (startDate != null) {
      query = query.where(
        'completed_at',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    return query
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Inject document ID
            return data;
          }).toList(),
        );
  }

  /// Delete a specific completion entry
  Future<void> deleteCompletion(String uid, String completionId) async {
    if (_isGuest) {
      await _localUserService.deleteHistoryEntry(completionId);
      return;
    }
    await _usersCollection
        .doc(uid)
        .collection('completions')
        .doc(completionId)
        .delete();
  }

  /// Get user stats (with daily reset check)
  Future<FirestoreUser?> getUserStats(String uid) async {
    if (_isGuest) {
      return getOrCreateUser(uid);
    }

    final doc = await _usersCollection.doc(uid).get();
    if (doc.exists) {
      var user = FirestoreUser.fromJson(doc.data()!);

      // Reset completedToday if it's a new day
      final today = _getTodayString();
      if (user.lastCompletionDay != today) {
        user = user.copyWith(completedToday: 0);
      }

      // Check weekly reset
      user = _checkWeeklyReset(user);

      return user;
    }
    return null;
  }

  /// Stream user stats (for real-time updates)
  Stream<FirestoreUser?> streamUserStats(String uid) {
    if (_isGuest) {
      // Ensure we have loaded initial data
      getOrCreateUser(uid); // Fire and forget to seed the stream
      return _localUserService.userStream;
    }

    final today = _getTodayString();

    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        var user = FirestoreUser.fromJson(doc.data()!);

        // Reset completedToday if it's a new day
        if (user.lastCompletionDay != today) {
          user = user.copyWith(completedToday: 0);
        }

        // Check weekly reset
        user = _checkWeeklyReset(user);

        return user;
      }
      return null;
    });
  }

  /// Update user subscription status
  Future<void> updateSubscription(
    String uid,
    bool isSubscriber,
    DateTime? expiry,
  ) async {
    if (_isGuest) {
      // Guests can't technically subscribe without an account usually,
      // but let's allow simulating it locally
      await _localUserService.updateUser(
        uid,
        (u) =>
            u.copyWith(isSubscriber: isSubscriber, subscriptionExpiry: expiry),
      );
      return;
    }
    await _usersCollection.doc(uid).update({
      'is_subscriber': isSubscriber,
      'subscription_expiry': expiry != null ? Timestamp.fromDate(expiry) : null,
    });
  }

  // ============ USER PROFILE ============

  /// Update user profile picture URL
  Future<void> updateUserPhoto(String uid, String photoUrl) async {
    if (_isGuest) {
      await _localUserService.updateUser(
        uid,
        (u) => u.copyWith(photoUrl: photoUrl),
      );
      return;
    }
    await _usersCollection.doc(uid).update({'photo_url': photoUrl});
  }

  /// Update user profile details
  Future<void> updateUserProfile({
    required String uid,
    String? firstName,
    String? lastName,
    String? username,
    String? email,
  }) async {
    if (_isGuest) {
      await _localUserService.updateUser(
        uid,
        (u) => u.copyWith(
          firstName: firstName,
          lastName: lastName,
          username: username,
          email: email,
        ),
      );
      return;
    }

    final Map<String, dynamic> data = {};
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    if (username != null) data['username'] = username;
    if (email != null) data['email'] = email;

    if (data.isNotEmpty) {
      await _usersCollection.doc(uid).set(data, SetOptions(merge: true));
    }
  }

  // ============ FAVORITES ============

  /// Toggle favorite status for a meditation
  Future<void> toggleFavorite(
    String uid,
    String meditationId,
    bool isFavorite,
  ) async {
    if (_isGuest) {
      await _localUserService.updateUser(uid, (u) {
        final list = List<String>.from(u.favoriteIds);
        if (isFavorite && !list.contains(meditationId)) {
          list.add(meditationId);
        } else if (!isFavorite) {
          list.remove(meditationId);
        }
        return u.copyWith(favoriteIds: list);
      });
      return;
    }
    final docRef = _usersCollection.doc(uid);
    if (isFavorite) {
      await docRef.update({
        'favorite_ids': FieldValue.arrayUnion([meditationId]),
      });
    } else {
      await docRef.update({
        'favorite_ids': FieldValue.arrayRemove([meditationId]),
      });
    }
  }

  /// Toggle "Listen Later" status for a meditation
  Future<void> toggleListenLater(
    String uid,
    String meditationId,
    bool isSaved,
  ) async {
    if (_isGuest) {
      await _localUserService.updateUser(uid, (u) {
        final list = List<String>.from(u.listenLaterIds);
        if (isSaved && !list.contains(meditationId)) {
          list.add(meditationId);
        } else if (!isSaved) {
          list.remove(meditationId);
        }
        return u.copyWith(listenLaterIds: list);
      });
      return;
    }
    final docRef = _usersCollection.doc(uid);
    if (isSaved) {
      await docRef.update({
        'listen_later_ids': FieldValue.arrayUnion([meditationId]),
      });
    } else {
      await docRef.update({
        'listen_later_ids': FieldValue.arrayRemove([meditationId]),
      });
    }
  }

  // ============ WEEKLY ACTIVITY ============

  /// Stream completions for the past N days (Real-time)
  Stream<Map<String, int>> streamCompletionsForDays(
    String uid, {
    int daysBack = 7,
  }) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - daysBack + 1);

    if (_isGuest) {
      // For guest, we wrap the local stream and filter
      return _localUserService.historyStream.map((history) {
        final docsData = history.where((e) {
          final date = DateTime.parse(
            e['completed_at_iso'] ??
                DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
          );
          return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
        }).toList();

        final Map<String, int> dailyMinutes = {};
        for (final data in docsData) {
          final completedAt = DateTime.parse(data['completed_at_iso']);
          final dateKey =
              '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}';
          final minutes = data['duration_minutes'] as int? ?? 0;
          dailyMinutes[dateKey] = (dailyMinutes[dateKey] ?? 0) + minutes;
        }
        return dailyMinutes;
      });
    }

    return _usersCollection
        .doc(uid)
        .collection('completions')
        .where(
          'completed_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .snapshots()
        .map((snapshot) {
          final docsData = snapshot.docs.map((d) => d.data()).toList();
          final Map<String, int> dailyMinutes = {};

          for (final data in docsData) {
            final completedAt = (data['completed_at'] as Timestamp).toDate();
            final dateKey =
                '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}';
            final minutes = data['duration_minutes'] as int? ?? 0;
            dailyMinutes[dateKey] = (dailyMinutes[dateKey] ?? 0) + minutes;
          }
          return dailyMinutes;
        });
  }

  /// Get completions for the past N days
  /// Returns a Map where key is date string (YYYY-MM-DD) and value is total minutes
  Future<Map<String, int>> getCompletionsForDays(
    String uid, {
    int daysBack = 7,
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - daysBack + 1);

    List<dynamic> docsData = [];

    if (_isGuest) {
      final history = await _localUserService.getHistory();
      // Filter by date
      docsData = history.where((e) {
        final date = DateTime.parse(
          e['completed_at_iso'] ??
              DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
        );
        return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
      }).toList();
    } else {
      final snapshot = await _usersCollection
          .doc(uid)
          .collection('completions')
          .where(
            'completed_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .get();
      docsData = snapshot.docs.map((d) => d.data()).toList();
    }

    final Map<String, int> dailyMinutes = {};

    for (final data in docsData) {
      DateTime completedAt;
      if (_isGuest) {
        completedAt = DateTime.parse(data['completed_at_iso']);
      } else {
        completedAt = (data['completed_at'] as Timestamp).toDate();
      }

      final dateKey =
          '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}';
      final minutes = data['duration_minutes'] as int? ?? 0;

      dailyMinutes[dateKey] = (dailyMinutes[dateKey] ?? 0) + minutes;
    }

    return dailyMinutes;
  }

  /// Get activity calendar data for mini calendar
  /// Returns a Map where key is date string (YYYY-MM-DD) and value is activity data
  Future<Map<String, ActivityData>> getActivityCalendarData(
    String uid, {
    int daysBack = 60,
  }) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - daysBack + 1);

    List<dynamic> docsData = [];

    if (_isGuest) {
      final history = await _localUserService.getHistory();
      docsData = history.where((e) {
        final date = DateTime.parse(
          e['completed_at_iso'] ??
              DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
        );
        return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
      }).toList();
    } else {
      final snapshot = await _usersCollection
          .doc(uid)
          .collection('completions')
          .where(
            'completed_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .get();
      docsData = snapshot.docs.map((d) => d.data()).toList();
    }

    final Map<String, ActivityData> activityData = {};

    for (final data in docsData) {
      DateTime completedAt;
      if (_isGuest) {
        completedAt = DateTime.parse(data['completed_at_iso']);
      } else {
        completedAt = (data['completed_at'] as Timestamp).toDate();
      }

      final dateKey =
          '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}';
      final minutes = data['duration_minutes'] as int? ?? 0;
      final ritualName = data['ritual_name'] as String? ?? 'Ritual';
      final source = data['source'] as String?;

      if (activityData.containsKey(dateKey)) {
        activityData[dateKey] = activityData[dateKey]!.addCompletion(
          minutes,
          ritualName,
          source: source,
        );
      } else {
        activityData[dateKey] = ActivityData(
          totalMinutes: minutes,
          sessionCount: 1,
          ritualWindowCount: source == 'ritual_window' ? 1 : 0,
          ritualNames: [ritualName],
        );
      }
    }

    return activityData;
  }

  // ============ MEDITATIONS COLLECTION ============

  CollectionReference<Map<String, dynamic>> get _meditationsCollection =>
      _firestore.collection('meditations');

  /// Get all meditations
  Future<List<Meditation>> getAllMeditations() async {
    final snapshot = await _meditationsCollection.get();
    return snapshot.docs
        .map((doc) => Meditation.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Fetch meditations with pagination
  Future<List<Meditation>> fetchMeditations({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _meditationsCollection
        .orderBy('title') // Consistent ordering is required for pagination
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Meditation.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Get meditations by category
  Future<List<Meditation>> getMeditationsByCategory(String category) async {
    final snapshot = await _meditationsCollection
        .where('category', isEqualTo: category)
        .get();
    return snapshot.docs
        .map((doc) => Meditation.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Get free meditations only
  Future<List<Meditation>> getFreeMeditations() async {
    final snapshot = await _meditationsCollection
        .where('is_premium', isEqualTo: false)
        .get();
    return snapshot.docs
        .map((doc) => Meditation.fromJson(doc.data(), doc.id))
        .toList();
  }

  /// Get a single meditation by ID
  Future<Meditation?> getMeditationById(String id) async {
    final doc = await _meditationsCollection.doc(id).get();
    if (doc.exists) {
      return Meditation.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  /// Get a single meditation by Title
  Future<Meditation?> getMeditationByTitle(String title) async {
    final snapshot = await _meditationsCollection
        .where('title', isEqualTo: title)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return Meditation.fromJson(doc.data(), doc.id);
    }
    return null;
  }

  /// Stream all meditations (for real-time updates)
  Stream<List<Meditation>> streamMeditations() {
    return _meditationsCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Meditation.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  /// Add a new meditation (admin use)
  Future<String> addMeditation(Meditation meditation) async {
    final docRef = await _meditationsCollection.add(meditation.toJson());
    return docRef.id;
  }

  /// Update an existing meditation (admin use)
  Future<void> updateMeditation(Meditation meditation) async {
    await _meditationsCollection.doc(meditation.id).update(meditation.toJson());
  }

  /// Delete a meditation (admin use)
  Future<void> deleteMeditation(String id) async {
    await _meditationsCollection.doc(id).delete();
  }
}
