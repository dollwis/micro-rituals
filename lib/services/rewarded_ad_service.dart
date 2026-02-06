import 'dart:async';
import 'package:flutter/foundation.dart';

/// Rewarded Ad Service
/// Handles rewarded video ads for unlocking content
///
/// Uses mock implementation for web testing.
/// For production on mobile, replace with actual Google AdMob integration.
class RewardedAdService {
  static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();

  bool _isInitialized = false;
  bool _isAdLoaded = false;
  bool _isAdShowing = false;

  // AdMob Test Ad Unit IDs (replace with real ones in production)
  // static const String _androidAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  // static const String _iosAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  /// Initialize the ad service
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      // Mock initialization for web
      debugPrint('RewardedAdService: Initialized (mock for web)');
      _isInitialized = true;
      return;
    }

    // TODO: For mobile, add real AdMob initialization:
    // await MobileAds.instance.initialize();
    _isInitialized = true;
    debugPrint('RewardedAdService: Initialized');
  }

  /// Pre-load a rewarded ad for faster display
  Future<void> loadRewardedAd() async {
    if (!_isInitialized) await initialize();
    if (_isAdLoaded) return;

    if (kIsWeb) {
      // Mock loading for web
      await Future.delayed(const Duration(milliseconds: 100));
      _isAdLoaded = true;
      debugPrint('RewardedAdService: Ad loaded (mock)');
      return;
    }

    // TODO: For mobile, load actual RewardedAd:
    // RewardedAd.load(
    //   adUnitId: Platform.isAndroid ? _androidAdUnitId : _iosAdUnitId,
    //   request: const AdRequest(),
    //   rewardedAdLoadCallback: RewardedAdLoadCallback(
    //     onAdLoaded: (ad) { _rewardedAd = ad; _isAdLoaded = true; },
    //     onAdFailedToLoad: (error) { debugPrint('Ad failed: $error'); },
    //   ),
    // );

    _isAdLoaded = true;
    debugPrint('RewardedAdService: Ad loaded');
  }

  /// Check if an ad is ready to show
  bool get isAdReady => _isAdLoaded && !_isAdShowing;

  /// Show a rewarded ad
  /// Returns true if reward was granted, false if user cancelled or error
  Future<bool> showRewardedAd({
    required Function() onRewardGranted,
    Function()? onAdDismissed,
    Function(String error)? onAdFailed,
  }) async {
    if (!_isInitialized) await initialize();
    if (!_isAdLoaded) await loadRewardedAd();

    if (_isAdShowing) {
      onAdFailed?.call('Ad already showing');
      return false;
    }

    _isAdShowing = true;

    if (kIsWeb) {
      // Mock ad experience for web testing
      return await _showMockAdDialog(
        onRewardGranted: onRewardGranted,
        onAdDismissed: onAdDismissed,
        onAdFailed: onAdFailed,
      );
    }

    // TODO: For mobile, show actual RewardedAd:
    // _rewardedAd?.show(onUserEarnedReward: (ad, reward) {
    //   onRewardGranted();
    // });

    // Fallback mock for now
    return await _showMockAdDialog(
      onRewardGranted: onRewardGranted,
      onAdDismissed: onAdDismissed,
      onAdFailed: onAdFailed,
    );
  }

  /// Mock ad dialog for web testing
  Future<bool> _showMockAdDialog({
    required Function() onRewardGranted,
    Function()? onAdDismissed,
    Function(String error)? onAdFailed,
  }) async {
    debugPrint('RewardedAdService: Showing mock ad...');

    // Simulate ad display time (0.5 seconds)
    await Future.delayed(const Duration(milliseconds: 500));

    _isAdShowing = false;
    _isAdLoaded = false; // Reset to load next ad

    // In mock mode, always grant reward
    onRewardGranted();
    onAdDismissed?.call();

    debugPrint('RewardedAdService: Mock ad completed, reward granted');
    return true;
  }

  /// Dispose of resources
  void dispose() {
    _isAdLoaded = false;
    _isAdShowing = false;
    // TODO: For mobile, dispose actual ad:
    // _rewardedAd?.dispose();
  }
}

/// Dialog helper for showing ad prompt to user
class RewardedAdDialog {
  /// Show a confirmation dialog before showing the ad
  /// Returns the session ID if user wants to watch, null if cancelled
  static Future<bool> showUnlockPrompt({
    required dynamic context,
    required String sessionTitle,
  }) async {
    // This will be called from the UI layer with BuildContext
    // For now, return true to indicate user wants to watch
    return true;
  }
}
