import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/audio_player_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/app_initialization_service.dart';
import 'widgets/loading_screen.dart';

import 'dart:async';

import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  //   await JustAudioBackground.init(
  //     androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
  //     androidNotificationChannelName: 'Audio playback',
  //     androidNotificationOngoing: true,
  //   );

  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // Set system UI overlay style for a clean look immediately
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppTheme.backgroundLight,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      runApp(const DailyMicroRitualsApp());
    },
    (error, stack) {
      if (error.toString().contains('Future already completed')) {
        // Known issue with google_sign_in_web
        debugPrint(
          'Warning: Ignored "Future already completed" error from Google Sign-In.',
        );
      } else {
        debugPrint('Uncaught error: $error');
        debugPrintStack(stackTrace: stack);
      }
    },
  );
}

/// Daily MicroRituals - Calm Technology Wellness Tracker
/// Redesigned with sage green theme and dashboard layout
class DailyMicroRitualsApp extends StatelessWidget {
  const DailyMicroRitualsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AudioPlayerProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Daily Pulse',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(themeProvider.currentVariant),
            darkTheme: AppTheme.darkTheme(themeProvider.currentVariant),
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const AppStartupFlow(),
          );
        },
      ),
    );
  }
}

class AppStartupFlow extends StatefulWidget {
  const AppStartupFlow({super.key});

  @override
  State<AppStartupFlow> createState() => _AppStartupFlowState();
}

class _AppStartupFlowState extends State<AppStartupFlow> {
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = AppInitializationService().initialize(context);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // Initialization complete, check Auth state
          return const AuthGate();
        }
        // Still initializing
        return const LoadingScreen();
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While checking auth usage immediately after init, we might want
        // to keep showing loading or just proceed.
        // Since Firebase is initialized, this usually returns data quickly.
        if (snapshot.connectionState == ConnectionState.waiting) {
          // We can reuse LoadingScreen here if Auth check lags
          return const LoadingScreen();
        }

        // If logged in, go to Dashboard; otherwise show Login
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
