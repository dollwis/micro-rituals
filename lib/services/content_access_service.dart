import 'package:shared_preferences/shared_preferences.dart';
import '../models/meditation.dart';

/// Content Access Controller Service
/// Manages access to sessions with Evergreen Free, Rewarded Ad Unlock, and Premium tiers
class ContentAccessService {
  static const String _unlockKeyPrefix = 'session_unlocked_until_';
  static const int unlockDurationHours = 24;

  // ============ EVERGREEN FREE SESSIONS ============
  // These 5 sessions are always accessible without ads or subscription

  static const List<String> evergreenFreeIds = [];

  /// Evergreen Free sessions data (for display on home screen)
  static const List<Map<String, dynamic>> evergreenFreeSessions = [];

  /// Get Meditation objects for Evergreen Free sessions
  static List<Meditation> getEvergreenFreeMeditations() {
    return evergreenFreeSessions
        .map(
          (data) => Meditation(
            id: data['id'] as String,
            title: data['title'] as String,
            duration: data['duration'] as int,
            category: data['category'] as String,
            audioUrl: '',
            coverImage: '',
            isPremium: false,
          ),
        )
        .toList();
  }

  // ============ ACCESS CHECKS ============

  /// Check if a session is Evergreen Free (always accessible)
  static bool isEvergreen(String sessionId) {
    return evergreenFreeIds.contains(sessionId);
  }

  /// Check if a session is temporarily unlocked via rewarded ad
  static Future<bool> isUnlockedViaAd(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_unlockKeyPrefix$sessionId';
    final unlockedUntil = prefs.getInt(key);

    if (unlockedUntil == null) return false;

    final expiryTime = DateTime.fromMillisecondsSinceEpoch(unlockedUntil);
    return DateTime.now().isBefore(expiryTime);
  }

  /// Get the unlock expiry time for a session (null if not unlocked)
  static Future<DateTime?> getUnlockExpiry(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_unlockKeyPrefix$sessionId';
    final unlockedUntil = prefs.getInt(key);

    if (unlockedUntil == null) return null;

    final expiryTime = DateTime.fromMillisecondsSinceEpoch(unlockedUntil);
    if (DateTime.now().isAfter(expiryTime)) return null;

    return expiryTime;
  }

  /// Get remaining unlock time as Duration (null if not unlocked)
  static Future<Duration?> getRemainingUnlockTime(String sessionId) async {
    final expiry = await getUnlockExpiry(sessionId);
    if (expiry == null) return null;
    return expiry.difference(DateTime.now());
  }

  /// Main access check - determines if user can access a session
  /// Priority: Evergreen Free > Subscriber > Ad Unlocked > Locked
  static Future<AccessResult> canAccess({
    required String sessionId,
    required bool isPremiumContent,
    required bool isAdRequired,
    required bool isSubscriber,
  }) async {
    // Evergreen Free - always accessible
    if (isEvergreen(sessionId)) {
      return AccessResult(
        canAccess: true,
        accessType: AccessType.evergreenFree,
      );
    }

    // Subscriber - full access to everything
    if (isSubscriber) {
      return AccessResult(canAccess: true, accessType: AccessType.subscriber);
    }

    // Premium content requires subscription
    if (isPremiumContent) {
      return AccessResult(
        canAccess: false,
        accessType: AccessType.premiumLocked,
      );
    }

    // Check for ad-based unlock
    if (isAdRequired) {
      final isUnlocked = await isUnlockedViaAd(sessionId);
      if (isUnlocked) {
        final remaining = await getRemainingUnlockTime(sessionId);
        return AccessResult(
          canAccess: true,
          accessType: AccessType.adUnlocked,
          remainingUnlockTime: remaining,
        );
      }
      return AccessResult(canAccess: false, accessType: AccessType.adLocked);
    }

    // Default: Content is free
    return AccessResult(canAccess: true, accessType: AccessType.free);
  }

  // ============ UNLOCK MANAGEMENT ============

  /// Unlock a session for 24 hours after watching rewarded ad
  static Future<void> unlockViaReward(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_unlockKeyPrefix$sessionId';
    final expiryTime = DateTime.now().add(
      const Duration(hours: unlockDurationHours),
    );
    await prefs.setInt(key, expiryTime.millisecondsSinceEpoch);
  }

  /// Clear unlock for a specific session (for testing)
  static Future<void> clearUnlock(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_unlockKeyPrefix$sessionId';
    await prefs.remove(key);
  }

  /// Clear all session unlocks (for testing)
  static Future<void> clearAllUnlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_unlockKeyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

/// Result of an access check
class AccessResult {
  final bool canAccess;
  final AccessType accessType;
  final Duration? remainingUnlockTime;

  AccessResult({
    required this.canAccess,
    required this.accessType,
    this.remainingUnlockTime,
  });
}

/// Types of access
enum AccessType {
  free, // Standard free content
  evergreenFree, // Always free, no unlock needed
  subscriber, // User has active subscription
  adUnlocked, // Temporarily unlocked via rewarded ad
  adLocked, // Can be unlocked by watching ad
  premiumLocked, // Requires subscription
}
