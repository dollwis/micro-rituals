import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Weekly performance insight card showing trends
class DashboardInsightCard extends StatelessWidget {
  final int minutesThisWeek;
  final int minutesLastWeek;

  const DashboardInsightCard({
    super.key,
    required this.minutesThisWeek,
    required this.minutesLastWeek,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate percentage change
    double percentChange = 0;
    if (minutesLastWeek > 0) {
      percentChange =
          ((minutesThisWeek - minutesLastWeek) / minutesLastWeek) * 100;
    } else if (minutesThisWeek > 0) {
      percentChange =
          100; // 100% increase if last week was 0 but this week has activity
    }

    final isPositive = percentChange >= 0;
    final absPercent = percentChange.abs().round();

    return Container(
      // width: double.infinity, // Flexible width
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getLavenderCardDecoration(context),
      child: Column(
        // Vertical stack for compact grid
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? Colors.white.withOpacity(0.1)
                  : const Color(
                      0xFFD1E4E4,
                    ), // Light teal/sage form the image background
            ),
            child: Icon(
              Icons.psychology, // Head/Brain icon
              color: AppTheme.getSageColor(context),
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          // Text Content
          Text(
            'Performance', // Shortened title
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.getTextColor(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: AppTheme.getMutedColor(context),
                fontFamily: 'Plus Jakarta Sans',
              ),
              children: [
                const TextSpan(text: 'Consistency '),
                TextSpan(
                  text: isPositive ? '+$absPercent% ' : '-$absPercent% ',
                  style: TextStyle(
                    color: isPositive
                        ? AppTheme.getPrimary(context)
                        : Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: 'this week.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
