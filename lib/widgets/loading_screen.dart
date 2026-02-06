import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We use a safe default background if theme isn't ready,
    // but ideally this is displayed inside a Theme provider or similar context
    // if we want to inherit colors.
    // Given the architecture, this might run BEFORE full theme load,
    // so we hardcode a neutral/brand color or assume AppTheme.backgroundLight.
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / Icon
            ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.1).animate(_animation),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.sagePrimary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.spa_rounded,
                  size: 40,
                  color: AppTheme.sagePrimary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // App Title
            Text(
              'Daily Pulse',
              style: TextStyle(
                fontFamily:
                    'Outfit', // Assuming this font is used as per other files
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finding your rhythm...',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppTheme.mutedText,
              ),
            ),
            const SizedBox(height: 48),
            // Subtle Progress Indicator
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.sagePrimary.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.sagePrimary),
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
