import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/audio_player_provider.dart';
import 'providers/preview_audio_provider.dart';
import 'providers/user_stats_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/app_initialization_service.dart';
import 'widgets/loading_screen.dart';

import 'dart:async';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Lock orientation to portrait mode
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize background audio for meditation/ritual sounds
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.dollwis.micro_rituals.audio',
        androidNotificationChannelName: 'Ritual Audio',
        androidNotificationOngoing: true,
      );

      // Set system UI overlay style for a clean look immediately
      // This will be updated dynamically by the ThemeProvider in build()

      runApp(const DailyMicroRitualsApp());
    },
    (error, stack) {
      _handleError(error, stack);
    },
  );
}

void _handleError(Object error, StackTrace stack) {
  if (error.toString().contains('Future already completed')) {
    debugPrint(
      'Warning: Ignored "Future already completed" error from Google Sign-In.',
    );
  } else {
    debugPrint('Uncaught error: $error');
    debugPrintStack(stackTrace: stack);
  }
}

/// Daily MicroRituals - Calm Technology Wellness Tracker
/// Redesigned with sage green theme and dashboard layout
class DailyMicroRitualsApp extends StatefulWidget {
  const DailyMicroRitualsApp({super.key});

  @override
  State<DailyMicroRitualsApp> createState() => _DailyMicroRitualsAppState();
}

class _DailyMicroRitualsAppState extends State<DailyMicroRitualsApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => PreviewAudioProvider()),
        ChangeNotifierProxyProvider<PreviewAudioProvider, AudioPlayerProvider>(
          create: (_) => AudioPlayerProvider(),
          update: (_, preview, audio) => audio!..setPreviewProvider(preview),
        ),
        ChangeNotifierProvider(create: (_) => UserStatsProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          if (!themeProvider.isInitialized) {
            return const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: LoadingScreen(),
            );
          }

          // Apply dynamic system UI overlay style
          SystemChrome.setSystemUIOverlayStyle(
            AppTheme.getSystemUiOverlayStyle(
              variant: themeProvider.currentVariant,
              isDarkMode: themeProvider.isDarkMode,
            ),
          );

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
