import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/ritual_window_service.dart';

/// Celebration card shown when ritual window is completed
class DashboardWellDoneCard extends StatelessWidget {
  final String windowLabel;
  final Duration timeUntilNextWindow;

  const DashboardWellDoneCard({
    super.key,
    required this.windowLabel,
    required this.timeUntilNextWindow,
  });

  @override
  Widget build(BuildContext context) {
    final countdown = RitualWindowService.formatCountdown(timeUntilNextWindow);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.getFeaturedCardDecoration(context),
      child: Column(
        children: [
          // Checkmark icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.getSageColor(context),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.getSageColor(context).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Well Done!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.getTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You completed your $windowLabel ritual.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.getTextColor(context).withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          // Next ritual countdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: AppTheme.getTextColor(context).withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Text(
                  'Next ritual in $countdown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.getTextColor(
                      context,
                    ).withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
