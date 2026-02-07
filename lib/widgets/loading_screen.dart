import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / Icon
            Container(
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
            // Optimized Progress Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.sagePrimary),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
