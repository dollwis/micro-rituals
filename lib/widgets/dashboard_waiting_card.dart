import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/ritual_window_service.dart';

/// Card shown when waiting for the next ritual window
class DashboardWaitingCard extends StatelessWidget {
  final String nextWindowLabel;
  final Duration timeUntilNextWindow;

  const DashboardWaitingCard({
    super.key,
    required this.nextWindowLabel,
    required this.timeUntilNextWindow,
  });

  @override
  Widget build(BuildContext context) {
    final countdown = RitualWindowService.formatCountdown(timeUntilNextWindow);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? AppTheme.sageGreen.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.sageGreen.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.sageGreen.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.hourglass_empty_rounded,
              color: AppTheme.sageGreenDark,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Next Ritual',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.getTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your $nextWindowLabel begins in',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.getTextColor(context).withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Countdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.sageGreenDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              countdown,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
