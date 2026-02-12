import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full Activity History Screen - Shows all weeks of activity history
/// Similar to FullHistoryScreen but for weekly aggregated data
class FullActivityHistoryScreen extends StatelessWidget {
  final Map<String, int> weeklyData; // Map<weekKey, totalMinutes>
  final Map<String, Map<String, int>>
  dailyDataByWeek; // Map<weekKey, Map<dateKey, minutes>>

  const FullActivityHistoryScreen({
    super.key,
    required this.weeklyData,
    required this.dailyDataByWeek,
  });

  @override
  Widget build(BuildContext context) {
    // Sort weeks by date (most recent first)
    final sortedWeeks = weeklyData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppTheme.isDark(context)
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.isDark(context)
            ? AppTheme.backgroundDark
            : AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.getTextColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Activity History',
          style: TextStyle(
            color: AppTheme.getTextColor(context),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: sortedWeeks.isEmpty
          ? Center(
              child: Text(
                'No activity history yet',
                style: TextStyle(
                  color: AppTheme.getMutedColor(context),
                  fontSize: 16,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedWeeks.length,
              itemBuilder: (context, index) {
                final weekKey = sortedWeeks[index];
                final totalMinutes = weeklyData[weekKey] ?? 0;

                return _WeekItemCard(
                  weekKey: weekKey,
                  totalMinutes: totalMinutes,
                  dailyData: dailyDataByWeek[weekKey] ?? {},
                );
              },
            ),
    );
  }
}

class _WeekItemCard extends StatefulWidget {
  final String weekKey;
  final int totalMinutes;
  final Map<String, int> dailyData;

  const _WeekItemCard({
    required this.weekKey,
    required this.totalMinutes,
    required this.dailyData,
  });

  @override
  State<_WeekItemCard> createState() => _WeekItemCardState();
}

class _WeekItemCardState extends State<_WeekItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final dateRange = _formatWeekRange(widget.weekKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.getPrimary(context),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateRange,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getTextColor(context),
                      ),
                    ),
                  ),
                  Text(
                    '${widget.totalMinutes} min',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) _buildExpandedContent(),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getPrimary(context).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildDayCircles(),
            const SizedBox(height: 16),
            _buildBarChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCircles() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weekDates = _getWeekDates(widget.weekKey);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final date = weekDates[index];
        final dateKey = _formatDateKey(date);
        final hasActivity =
            widget.dailyData.containsKey(dateKey) &&
            widget.dailyData[dateKey]! > 0;

        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: hasActivity
                ? AppTheme.getPrimary(context)
                : AppTheme.getMutedColor(context).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              days[index],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: hasActivity
                    ? Colors.white
                    : AppTheme.getMutedColor(context),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBarChart() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weekDates = _getWeekDates(widget.weekKey);

    int maxMinutes = 1;
    for (final date in weekDates) {
      final dateKey = _formatDateKey(date);
      final minutes = widget.dailyData[dateKey] ?? 0;
      if (minutes > maxMinutes) maxMinutes = minutes;
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.getPrimary(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final date = weekDates[index];
          final dateKey = _formatDateKey(date);
          final minutes = widget.dailyData[dateKey] ?? 0;
          final heightRatio = maxMinutes > 0 ? minutes / maxMinutes : 0.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (minutes > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '$minutes',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextColor(
                            context,
                          ).withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      height: minutes > 0
                          ? (30 * heightRatio).clamp(6.0, 30.0)
                          : 3,
                      decoration: BoxDecoration(
                        color: minutes > 0
                            ? AppTheme.getPrimary(context)
                            : AppTheme.getMutedColor(
                                context,
                              ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    days[index],
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getMutedColor(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // Helper methods
  List<DateTime> _getWeekDates(String weekKey) {
    final parts = weekKey.split('-W');
    if (parts.length != 2) return [];

    final year = int.parse(parts[0]);
    final weekNum = int.parse(parts[1]);

    final jan4 = DateTime(year, 1, 4);
    final mondayOfWeek1 = jan4.subtract(Duration(days: jan4.weekday - 1));
    final weekStart = mondayOfWeek1.add(Duration(days: (weekNum - 1) * 7));

    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatWeekRange(String weekKey) {
    final dates = _getWeekDates(weekKey);
    if (dates.isEmpty) return weekKey;

    final start = dates.first;
    final end = dates.last;

    final monthName = _getMonthName(start.month);

    if (start.month == end.month) {
      return '${start.day.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}. $monthName';
    } else {
      final endMonthName = _getMonthName(end.month);
      return '${start.day.toString().padLeft(2, '0')} $monthName - ${end.day.toString().padLeft(2, '0')} $endMonthName';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
