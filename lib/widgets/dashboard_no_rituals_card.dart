import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Empty state card displayed when no rituals are available
class DashboardNoRitualsCard extends StatelessWidget {
  const DashboardNoRitualsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.getCardDecoration(context),
      child: Column(
        children: [
          Icon(
            Icons.spa_outlined,
            size: 48,
            color: AppTheme.getMutedColor(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No Rituals Available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.getTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your library is empty. Add new rituals to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.getMutedColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
