import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._internal();

  factory AdService() => _instance;

  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;
  int _accumulatedMinutes = 0;
  // Temporarily set to 1 for testing
  static const int _adThresholdMinutes = 1;
  static const String _prefKeyAdMinutes = 'ad_listening_minutes';

  // Test Ad Unit IDs
  String get _adUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return '';
  }

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('AdService: Initializing (Web Mock Mode)');
      await _loadAccumulatedMinutes();
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) return;

    await MobileAds.instance.initialize();
    await _loadAccumulatedMinutes();
    _loadInterstitialAd();
  }

  Future<void> _loadAccumulatedMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    _accumulatedMinutes = prefs.getInt(_prefKeyAdMinutes) ?? 0;
  }

  Future<void> _saveAccumulatedMinutes() async {
    // Save on Web too for testing persistence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyAdMinutes, _accumulatedMinutes);
  }

  /// Called periodically by AudioPlayerProvider to track listening time.
  /// Increment by 1 minute.
  void trackListeningTime() {
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) return;

    _accumulatedMinutes++;
    _saveAccumulatedMinutes();
    debugPrint(
      'AdService: Accumulated minutes: $_accumulatedMinutes / $_adThresholdMinutes',
    );
  }

  void _loadInterstitialAd() {
    if (_isAdLoading || _interstitialAd != null || kIsWeb) return;
    if (_adUnitId.isEmpty) return;

    _isAdLoading = true;
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdService: InterstitialAd loaded.');
          _interstitialAd = ad;
          _isAdLoading = false;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  debugPrint('AdService: Ad dismissed.');
                  ad.dispose();
                  _interstitialAd = null;
                  // Preload next ad
                  _loadInterstitialAd();
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  debugPrint('AdService: Ad failed to show: $error');
                  ad.dispose();
                  _interstitialAd = null;
                  _loadInterstitialAd();
                },
              );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: InterstitialAd failed to load: $error');
          _isAdLoading = false;
        },
      ),
    );
  }

  /// Checks if the threshold is met and shows the ad if ready.
  /// Should be called on App Resume or App Start.
  void checkAndShowAd() {
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) return;

    // Web Mock
    if (kIsWeb) {
      debugPrint(
        'AdService (Web): Checking ad trigger. Minutes: $_accumulatedMinutes',
      );
      if (_accumulatedMinutes >= _adThresholdMinutes) {
        debugPrint('AdService (Web): *** MOCK INTERSTITIAL AD SHOWN ***');
        _accumulatedMinutes = 0;
        _saveAccumulatedMinutes();
      }
      return;
    }

    debugPrint('AdService: Checking ad trigger. Minutes: $_accumulatedMinutes');

    if (_accumulatedMinutes >= _adThresholdMinutes) {
      if (_interstitialAd != null) {
        debugPrint('AdService: Showing Interstitial Ad.');
        _interstitialAd!.show();
        // Reset counter
        _accumulatedMinutes = 0;
        _saveAccumulatedMinutes();
      } else {
        debugPrint(
          'AdService: Threshold met but ad not ready. Attempting load.',
        );
        _loadInterstitialAd();
      }
    } else {
      // Ensure we have an ad ready for when the threshold IS met
      if (_interstitialAd == null) {
        _loadInterstitialAd();
      }
    }
  }
}
