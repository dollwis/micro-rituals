import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WeeklyActivityCard extends StatefulWidget {
  final String weekKey;
  final int totalMinutes;
  final Map<String, int> dailyData;
  final bool initiallyExpanded;
  final bool isCurrentWeek;

  const WeeklyActivityCard({
    super.key,
    required this.weekKey,
    required this.totalMinutes,
    required this.dailyData,
    this.initiallyExpanded = false,
    this.isCurrentWeek = false,
  });

  @override
  State<WeeklyActivityCard> createState() => _WeeklyActivityCardState();
}

class _WeeklyActivityCardState extends State<WeeklyActivityCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_buildHeader(), if (_isExpanded) _buildExpandedContent()],
    );
  }

  Widget _buildHeader() {
    final dateRange = _formatWeekRange(widget.weekKey);

    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
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
    );
  }

  Widget _buildExpandedContent() {
    // Calculate stats
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weekDates = _getWeekDates(widget.weekKey);
    final avgDaily = widget.totalMinutes / 7.0;

    // Calculate session count (sum of ritualWindowCount if available, checking data structure)
    // Since we only receive total minutes per day in dailyData, we might need to approximate or pass more data.
    // For now, let's count days with activity as a proxy or just use the passed map.
    // Ideally, pass full ActivityData, but for UI match let's assume valid session count needs to be passed in.
    // Wait, the user wants "same box as marked with green".
    // Let's enhance the card to look like _buildMindfulMinutesCard.

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context), // Match top card color
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.getPrimary(context).withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            Text(
              'WEEKLY ACTIVITY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.getMutedColor(context),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),

            // Day Circles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final date = weekDates[index];
                final dateKey = _formatDateKey(date);
                final hasActivity =
                    widget.dailyData.containsKey(dateKey) &&
                    widget.dailyData[dateKey]! > 0;
                final isFuture = date.isAfter(DateTime.now());

                return Column(
                  children: [
                    Text(
                      days[index],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.getMutedColor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasActivity
                            ? AppTheme.getPrimary(context)
                            : Colors.transparent,
                        border: hasActivity
                            ? null
                            : Border.all(
                                color: isFuture
                                    ? AppTheme.getMutedColor(
                                        context,
                                      ).withValues(alpha: 0.1)
                                    : AppTheme.getPrimary(
                                        context,
                                      ).withValues(alpha: 0.5),
                                width: 2,
                              ),
                      ),
                      child: hasActivity
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ],
                );
              }),
            ),

            const SizedBox(height: 16),

            // Big Total Minutes
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${widget.totalMinutes}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getTextColor(context),
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.isCurrentWeek)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.isDark(context)
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: AppTheme.getPrimary(context),
                          size: 14,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'This Week',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.getPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // Bar Chart
            _buildDetailedBarChart(weekDates),

            const SizedBox(height: 16),

            // Footer Stats
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.isDark(context)
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AVG DAILY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.getMutedColor(
                              context,
                            ).withValues(alpha: 0.6),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${avgDaily.toStringAsFixed(1)}m',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.getTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Note: 'Sessions' count is not currently passed to this widget.
                  // Ideally we should pass it. For now, we can omit or calculate strictly based on daysactive if needed.
                  // Or assuming dailyData values are minutes, we can't know precise session count if multiple sessions/day.
                  // But let's assume 1 session per active day for approximation if needed, or better, update constructor.
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedBarChart(List<DateTime> weekDates) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    int maxMinutes = 1;
    for (final date in weekDates) {
      final dateKey = _formatDateKey(date);
      final minutes = widget.dailyData[dateKey] ?? 0;
      if (minutes > maxMinutes) maxMinutes = minutes;
    }

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.getPrimary(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final date = weekDates[index];
          final dateKey = _formatDateKey(date);
          final minutes = widget.dailyData[dateKey] ?? 0;
          final heightRatio = maxMinutes > 0 ? minutes / maxMinutes : 0.0;
          final isToday = _isToday(date);

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
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextColor(
                            context,
                          ).withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      height: minutes > 0
                          ? (40 * heightRatio).clamp(8.0, 40.0)
                          : 4,
                      decoration: BoxDecoration(
                        color: minutes > 0
                            ? (isToday
                                  ? AppTheme.getPrimary(context)
                                  : AppTheme.getPrimary(
                                      context,
                                    ).withValues(alpha: 0.6))
                            : AppTheme.getMutedColor(
                                context,
                              ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    days[index],
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: isToday
                          ? AppTheme.getPrimary(context)
                          : AppTheme.getMutedColor(context),
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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Helper methods
  List<DateTime> _getWeekDates(String weekKey) {
    // weekKey format: "2026-W06" (year-week)
    final parts = weekKey.split('-W');
    if (parts.length != 2) return [];

    final year = int.parse(parts[0]);
    final weekNum = int.parse(parts[1]);

    // Calculate first day of the week (Monday)
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
