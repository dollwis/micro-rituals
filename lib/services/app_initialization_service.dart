import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../firebase_options.dart';
import 'notification_service.dart';
import '../providers/theme_provider.dart';
import 'cache_cleanup_service.dart';

/// Orchestrates the app startup process.
/// Handles initialization of Firebase, crucial providers, and other services.
class AppInitializationService {
  static final AppInitializationService _instance =
      AppInitializationService._internal();

  factory AppInitializationService() => _instance;

  AppInitializationService._internal();

  /// Runs all initialization tasks.
  /// Returns a Future that completes when the app is ready to start.
  Future<void> initialize(BuildContext context) async {
    final minSplashDuration = const Duration(seconds: 2);
    final stopwatch = Stopwatch()..start();

    try {
      // 1. Initialize Firebase
      // Check if already initialized to avoid errors during hot restart
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // 2. Initialize Notification Service
      // We don't await this if it takes too long, or we do if it's critical.
      // Usually fine to await.
      await NotificationService().initialize();

      // 3. Load Theme Preferences safely
      // We access the provider which should be above this in the tree (or passed in)
      if (context.mounted) {
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        await themeProvider.load();
      }

      // 4. Clean up audio cache (limit to 500MB)
      try {
        // Run in background, don't await blocking critical startup if possible,
        // but since we want to clear space, awaiting briefly is fine.
        // Let's not await it to keep startup fast.
        CacheCleanupService().cleanCache();
      } catch (e) {
        debugPrint('Cache cleanup failed: $e');
      }

      // 4. Any other pre-fetching of user data could go here...
    } catch (e, stackTrace) {
      debugPrint('Initialization failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      // In a real app, we might want to show an error screen or retry logic.
    } finally {
      stopwatch.stop();
      // 5. Ensure the splash screen is shown for at least minSplashDuration
      // This prevents the screen from flickering if init is instant.
      final elapsed = stopwatch.elapsed;
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
      }
    }
  }
}
