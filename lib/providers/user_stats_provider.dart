import 'package:flutter/foundation.dart';
import '../models/firestore_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'dart:async';

/// Provider for UserStats (FirestoreUser) to avoid repeated StreamBuilders
/// Follows the same pattern as AudioPlayerProvider
class UserStatsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  FirestoreUser? _userStats;
  StreamSubscription<FirestoreUser?>? _statsSubscription;

  FirestoreUser? get userStats => _userStats;
  bool get isLoading => _userStats == null;

  UserStatsProvider() {
    _init();
  }

  void _init() {
    final uid = _authService.currentUserId;
    if (uid != null) {
      // Subscribe to user stats stream
      _statsSubscription = _firestoreService
          .streamUserStats(uid)
          .listen(
            (user) {
              _userStats = user;
              debugPrint(
                'UserStatsProvider: Loaded user stats - Minutes this week: ${user?.minutesThisWeek}, Total: ${user?.totalMinutes}',
              );
              notifyListeners();
            },
            onError: (error) {
              debugPrint(
                'UserStatsProvider: Error streaming user stats: $error',
              );
            },
          );
    }
  }

  /// Manually refresh user stats (optional)
  Future<void> refresh() async {
    final uid = _authService.currentUserId;
    if (uid != null) {
      final user = await _firestoreService.getUserStats(uid);
      _userStats = user;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    super.dispose();
  }
}
