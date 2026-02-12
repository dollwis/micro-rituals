import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Dialog shown when a free user tries to access premium features
class PremiumRequiredDialog extends StatelessWidget {
  final String feature;

  const PremiumRequiredDialog({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.getCardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.getPrimary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.diamond_rounded,
              color: AppTheme.getPrimary(context),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Premium Feature',
              style: TextStyle(
                color: AppTheme.getTextColor(context),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlock $feature with Premium',
            style: TextStyle(
              color: AppTheme.getTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upgrade to Premium to enjoy:',
            style: TextStyle(
              color: AppTheme.getMutedColor(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            context,
            icon: Icons.download_rounded,
            text: 'Offline downloads',
          ),
          const SizedBox(height: 8),
          _buildFeatureItem(
            context,
            icon: Icons.headphones_rounded,
            text: 'Unlimited meditation sessions',
          ),
          const SizedBox(height: 8),
          _buildFeatureItem(
            context,
            icon: Icons.lock_open_rounded,
            text: 'Access to exclusive content',
          ),
          const SizedBox(height: 8),
          _buildFeatureItem(
            context,
            icon: Icons.ad_units_rounded,
            text: 'Ad-free experience',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Maybe Later',
            style: TextStyle(
              color: AppTheme.getMutedColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Navigate to subscription screen
            Navigator.pushNamed(context, '/subscription');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.getPrimary(context),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Upgrade Now',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.getPrimary(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppTheme.getTextColor(context),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
