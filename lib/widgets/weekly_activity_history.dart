import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/full_activity_history_screen.dart';
import 'weekly_activity_card.dart';

/// Weekly Activity History widget showing expandable list of past weeks
/// Each row shows week date range and total minutes
/// Expands to show day circles and bar chart
class WeeklyActivityHistory extends StatelessWidget {
  final Map<String, int> weeklyData; // Map<weekKey, totalMinutes>
  final Map<String, Map<String, int>>
  dailyDataByWeek; // Map<weekKey, Map<dateKey, minutes>>
  final int? limit;

  const WeeklyActivityHistory({
    super.key,
    required this.weeklyData,
    required this.dailyDataByWeek,
    this.limit,
  });

  @override
  Widget build(BuildContext context) {
    if (weeklyData.isEmpty) {
      return const SizedBox.shrink();
    }

    var sortedWeeks = weeklyData.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    if (limit != null) {
      sortedWeeks = sortedWeeks.take(limit!).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Activity History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.getTextColor(context),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullActivityHistoryScreen(
                        weeklyData: weeklyData,
                        dailyDataByWeek: dailyDataByWeek,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.getIconBgColor(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'All activity',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.getPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 12,
                        color: AppTheme.getPrimary(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ...sortedWeeks.map((weekKey) {
          return WeeklyActivityCard(
            weekKey: weekKey,
            totalMinutes: weeklyData[weekKey]!,
            dailyData: dailyDataByWeek[weekKey] ?? {},
            initiallyExpanded: false,
          );
        }),
      ],
    );
  }
}
