import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore user model
/// Collection: 'users'
class FirestoreUser {
  final String uid;
  final int currentStreak;
  final int totalCompleted;
  final int totalMinutes;
  final int completedToday;
  final DateTime? lastCompletionDate;
  final String? lastCompletionDay; // YYYY-MM-DD format for daily reset
  final DateTime? createdAt; // User's first login/activity date

  // Subscription fields
  final bool isSubscriber;
  final DateTime? subscriptionExpiry;
  final String? photoUrl;

  // Profile fields
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? email;

  // Weekly Stats
  final int minutesThisWeek;
  final int minutesLastWeek;
  final DateTime? lastWeeklyReset;
  // Preferences
  final List<String> favoriteIds;
  final List<String> listenLaterIds;

  const FirestoreUser({
    required this.uid,
    this.currentStreak = 0,
    this.totalCompleted = 0,
    this.totalMinutes = 0,
    this.completedToday = 0,
    this.lastCompletionDate,
    this.lastCompletionDay,
    this.createdAt,
    this.isSubscriber = false,
    this.subscriptionExpiry,
    this.photoUrl,
    this.firstName,
    this.lastName,
    this.username,
    this.email,
    this.minutesThisWeek = 0,
    this.minutesLastWeek = 0,
    this.lastWeeklyReset,
    this.favoriteIds = const [],
    this.listenLaterIds = const [],
  });

  /// Check if subscription is active
  /// Returns true if user is a subscriber
  /// If subscriptionExpiry is null, treats as lifetime subscription
  /// If subscriptionExpiry is set, checks if it's in the future
  bool get hasActiveSubscription {
    if (!isSubscriber) return false;
    // If no expiry date, treat as lifetime subscription
    if (subscriptionExpiry == null) return true;
    // If expiry date exists, check if still valid
    return subscriptionExpiry!.isAfter(DateTime.now());
  }

  /// Get display name (preferred: username > full name > 'User')
  String get displayName {
    if (username != null && username!.isNotEmpty) return username!;
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    return 'User';
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'current_streak': currentStreak,
      'total_completed': totalCompleted,
      'total_minutes': totalMinutes,
      'completed_today': completedToday,
      'last_completion_date': lastCompletionDate != null
          ? Timestamp.fromDate(lastCompletionDate!)
          : null,
      'last_completion_day': lastCompletionDay,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'is_subscriber': isSubscriber,
      'subscription_expiry': subscriptionExpiry != null
          ? Timestamp.fromDate(subscriptionExpiry!)
          : null,
      'photo_url': photoUrl,
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'email': email,
      'minutes_this_week': minutesThisWeek,
      'minutes_last_week': minutesLastWeek,
      'last_weekly_reset': lastWeeklyReset != null
          ? Timestamp.fromDate(lastWeeklyReset!)
          : null,
      'favorite_ids': favoriteIds,
      'listen_later_ids': listenLaterIds,
    };
  }

  factory FirestoreUser.fromJson(Map<String, dynamic> json) {
    return FirestoreUser(
      uid: json['uid'] as String,
      currentStreak: json['current_streak'] as int? ?? 0,
      totalCompleted: json['total_completed'] as int? ?? 0,
      totalMinutes: json['total_minutes'] as int? ?? 0,
      completedToday: json['completed_today'] as int? ?? 0,
      lastCompletionDate: json['last_completion_date'] != null
          ? (json['last_completion_date'] as Timestamp).toDate()
          : null,
      lastCompletionDay: json['last_completion_day'] as String?,
      createdAt: json['created_at'] != null
          ? (json['created_at'] as Timestamp).toDate()
          : null,
      isSubscriber: json['is_subscriber'] as bool? ?? false,
      subscriptionExpiry: json['subscription_expiry'] != null
          ? (json['subscription_expiry'] as Timestamp).toDate()
          : null,
      photoUrl: json['photo_url'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
      minutesThisWeek: json['minutes_this_week'] as int? ?? 0,
      minutesLastWeek: json['minutes_last_week'] as int? ?? 0,
      lastWeeklyReset: json['last_weekly_reset'] != null
          ? (json['last_weekly_reset'] as Timestamp).toDate()
          : null,
      favoriteIds:
          (json['favorite_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      listenLaterIds:
          (json['listen_later_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  FirestoreUser copyWith({
    String? uid,
    int? currentStreak,
    int? totalCompleted,
    int? totalMinutes,
    int? completedToday,
    DateTime? lastCompletionDate,
    String? lastCompletionDay,
    DateTime? createdAt,
    bool? isSubscriber,
    DateTime? subscriptionExpiry,
    String? photoUrl,
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    int? minutesThisWeek,
    int? minutesLastWeek,
    DateTime? lastWeeklyReset,
    List<String>? favoriteIds,
    List<String>? listenLaterIds,
  }) {
    return FirestoreUser(
      uid: uid ?? this.uid,
      currentStreak: currentStreak ?? this.currentStreak,
      totalCompleted: totalCompleted ?? this.totalCompleted,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      completedToday: completedToday ?? this.completedToday,
      lastCompletionDate: lastCompletionDate ?? this.lastCompletionDate,
      lastCompletionDay: lastCompletionDay ?? this.lastCompletionDay,
      createdAt: createdAt ?? this.createdAt,
      isSubscriber: isSubscriber ?? this.isSubscriber,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      photoUrl: photoUrl ?? this.photoUrl,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      email: email ?? this.email,
      minutesThisWeek: minutesThisWeek ?? this.minutesThisWeek,
      minutesLastWeek: minutesLastWeek ?? this.minutesLastWeek,
      lastWeeklyReset: lastWeeklyReset ?? this.lastWeeklyReset,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      listenLaterIds: listenLaterIds ?? this.listenLaterIds,
    );
  }
}
