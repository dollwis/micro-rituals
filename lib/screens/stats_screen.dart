import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/firestore_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/ritual_history_list.dart';
import '../widgets/weekly_activity_history.dart';

import 'full_history_screen.dart';

/// Stats/Reflection Screen - Detailed stats and ritual history
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // Sage green accent colors

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  FirestoreUser? _userStats;
  Map<String, int> _weeklyCompletions = {};
  Map<String, ActivityData> _calendarData = {};
  bool _isLoadingWeeklyData = false; // Don't show spinner by default

  // Calendar month navigation
  DateTime _selectedMonth = DateTime.now();

  // Computed from user stats
  int get totalMinutes => _userStats?.totalMinutes ?? 0;
  int get totalSessions => _userStats?.totalCompleted ?? 0;
  int get currentStreak => _userStats?.currentStreak ?? 0;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
    _loadWeeklyActivity();
  }

  void _loadUserStats() {
    final uid = _authService.currentUserId;
    if (uid != null) {
      _firestoreService.streamUserStats(uid).listen((user) {
        if (mounted) {
          setState(() => _userStats = user);
        }
      });
    }
  }

  StreamSubscription? _weeklyCompletionsSubscription;

  @override
  void dispose() {
    _weeklyCompletionsSubscription?.cancel();
    super.dispose();
  }

  void _loadWeeklyActivity() {
    final uid = _authService.currentUserId;
    if (uid == null) return;

    // Load initial calendar data (once)
    _firestoreService.getActivityCalendarData(uid, daysBack: 365).then((data) {
      if (mounted) {
        setState(() {
          _calendarData = data;
        });
      }
    });

    // Stream weekly completions (real-time)
    _weeklyCompletionsSubscription?.cancel();
    _weeklyCompletionsSubscription = _firestoreService
        .streamCompletionsForDays(uid, daysBack: 7)
        .listen(
          (completions) {
            if (mounted) {
              setState(() {
                _weeklyCompletions = completions;
                _isLoadingWeeklyData = false;
              });
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() => _isLoadingWeeklyData = false);
            }
          },
        );
  }

  /// Get current week dates (Monday to Sunday)
  List<DateTime> _getWeekDates() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
  }

  /// Format date as YYYY-MM-DD
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if a specific date has activity
  bool _hasActivityOnDate(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _weeklyCompletions.containsKey(dateKey) &&
        _weeklyCompletions[dateKey]! > 0;
  }

  /// Get minutes for a specific date
  int _getMinutesForDate(DateTime date) {
    final dateKey = _formatDateKey(date);
    return _weeklyCompletions[dateKey] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),

              // Mindful Minutes Card (Top Summary)
              _buildMindfulMinutesCard(),

              const SizedBox(height: 16),

              // Weekly Activity History (List including current week)
              _buildWeeklyActivityHistory(),

              const SizedBox(height: 8),

              // Ritual History Header (Detailed Sessions)
              _buildHistoryHeader(),

              // Ritual History List
              _buildRitualHistory(),

              // Performance Insight
              _buildPerformanceInsight(),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Reflection',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.getTextColor(context),
              letterSpacing: -0.5,
            ),
          ),
          // Streak Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.orange.withValues(alpha: 0.9),
                  AppTheme.orange,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.orange.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '$currentStreak',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonthDay(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildDayCircle(
    String day,
    bool isCompleted,
    bool isToday,
    bool isFuture,
  ) {
    return Column(
      children: [
        Text(
          day,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isToday
                ? AppTheme.getPrimary(context)
                : AppTheme.getMutedColor(context),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? AppTheme.getPrimary(context)
                : Colors.transparent,
            border: isCompleted
                ? null
                : Border.all(
                    color: isFuture
                        ? AppTheme.getMutedColor(context).withValues(alpha: 0.1)
                        : AppTheme.getPrimary(context).withValues(alpha: 0.5),
                    width: 2,
                  ),
          ),
          child: isCompleted
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ],
    );
  }

  void _showMiniCalendar() {
    // Reset to current month when opening
    setState(() => _selectedMonth = DateTime.now());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildMiniCalendarSheet(),
    );
  }

  Widget _buildMiniCalendarSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        final monthName = _getMonthName(_selectedMonth.month);
        final year = _selectedMonth.year;

        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.getMutedColor(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header with month navigation
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left,
                        color: AppTheme.getPrimary(context),
                      ),
                      onPressed: () {
                        setSheetState(() {
                          _selectedMonth = DateTime(
                            _selectedMonth.year,
                            _selectedMonth.month - 1,
                          );
                        });
                      },
                    ),
                    Text(
                      '$monthName $year',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.getTextColor(context),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color: _canGoToNextMonth()
                            ? AppTheme.getPrimary(context)
                            : AppTheme.getMutedColor(
                                context,
                              ).withValues(alpha: 0.3),
                      ),
                      onPressed: _canGoToNextMonth()
                          ? () {
                              setSheetState(() {
                                _selectedMonth = DateTime(
                                  _selectedMonth.year,
                                  _selectedMonth.month + 1,
                                );
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              // Day of week headers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                      .map(
                        (day) => SizedBox(
                          width: 36,
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.getMutedColor(context),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              // Calendar Grid
              Expanded(child: _buildMonthCalendarGrid()),
              // Legend
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('None', 0),
                    const SizedBox(width: 16),
                    _buildLegendItem('1-15m', 1),
                    const SizedBox(width: 16),
                    _buildLegendItem('16-60m', 2),
                    const SizedBox(width: 16),
                    _buildLegendItem('60m+', 3),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canGoToNextMonth() {
    final now = DateTime.now();
    return _selectedMonth.year < now.year ||
        (_selectedMonth.year == now.year && _selectedMonth.month < now.month);
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

  Widget _buildMonthCalendarGrid() {
    // Get first day of the month
    final firstDayOfMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    );
    // Get number of days in the month
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    // Get the weekday of the first day (1 = Monday, 7 = Sunday)
    final firstWeekday = firstDayOfMonth.weekday;
    // Calculate empty slots before the first day
    final emptySlots = firstWeekday - 1;
    // Total items needed (empty slots + days in month)
    final totalSlots = emptySlots + daysInMonth;

    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: totalSlots,
        itemBuilder: (context, index) {
          // Empty slot before first day
          if (index < emptySlots) {
            return const SizedBox();
          }

          final day = index - emptySlots + 1;
          final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
          final dateKey = _formatDateKey(date);
          final activity = _calendarData[dateKey];
          final intensity = activity?.intensityLevel ?? 0;

          // Check if this is today
          final isToday = isCurrentMonth && day == now.day;
          // Check if this is a future date
          final isFuture = date.isAfter(now);

          return GestureDetector(
            onTap: activity != null
                ? () => _showDayDetail(date, activity)
                : null,
            child: Container(
              decoration: BoxDecoration(
                color: isFuture
                    ? Colors.transparent
                    : _getIntensityColor(intensity),
                borderRadius: BorderRadius.circular(6),
                border: isToday
                    ? Border.all(color: AppTheme.getPrimary(context), width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isFuture
                        ? AppTheme.getMutedColor(context).withValues(alpha: 0.3)
                        : intensity > 1
                        ? Colors.white
                        : AppTheme.getTextColor(context).withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getIntensityColor(int level) {
    final primary = AppTheme.getPrimary(context);
    switch (level) {
      case 1:
        return primary.withValues(alpha: 0.3);
      case 2:
        return primary.withValues(alpha: 0.6);
      case 3:
        return primary;
      default:
        // Improved visibility for "None" cells
        return AppTheme.isDark(context)
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.1);
    }
  }

  Widget _buildLegendItem(String label, int intensity) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _getIntensityColor(intensity),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.getMutedColor(context),
          ),
        ),
      ],
    );
  }

  void _showDayDetail(DateTime date, ActivityData? activity) {
    if (activity == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text(
          _formatMonthDay(date),
          style: TextStyle(color: AppTheme.getTextColor(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${activity.totalMinutes} minutes',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.getTextColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${activity.sessionCount} session${activity.sessionCount > 1 ? 's' : ''}',
              style: TextStyle(color: AppTheme.getMutedColor(context)),
            ),
            const SizedBox(height: 12),
            ...activity.ritualNames.map(
              (name) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppTheme.getPrimary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(color: AppTheme.getTextColor(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: AppTheme.getPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '$minutes';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  Widget _buildMindfulMinutesCard() {
    // Use Firestore data directly for weekly minutes (authoritative source)
    final int weeklyMinutes = _userStats?.minutesThisWeek ?? 0;

    // Calculate average daily minutes (over 7 days)
    final double avgDaily = weeklyMinutes / 7.0;

    // Still need weekDates for the week display and date range
    final weekDates = _getWeekDates();

    final weeklySessionCount = _calendarData.entries
        .where((e) => weekDates.map(_formatDateKey).contains(e.key))
        .fold(0, (sum, e) => sum + e.value.ritualWindowCount);

    // Weekly activity setup
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final startDate = weekDates.first;
    final endDate = weekDates.last;
    final dateRange =
        '${_formatMonthDay(startDate)} - ${_formatMonthDay(endDate)}';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weekly Activity Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'WEEKLY ACTIVITY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getMutedColor(context),
                    letterSpacing: 2,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      dateRange,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.getMutedColor(
                          context,
                        ).withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showMiniCalendar(),
                      child: Icon(
                        Icons.calendar_month,
                        size: 18,
                        color: AppTheme.getPrimary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Weekly Day Circles
            _isLoadingWeeklyData
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final date = weekDates[index];
                      final isCompleted = _hasActivityOnDate(date);
                      final isToday = _isToday(date);
                      final isFuture = date.isAfter(DateTime.now());
                      return _buildDayCircle(
                        days[index],
                        isCompleted,
                        isToday,
                        isFuture,
                      );
                    }),
                  ),

            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _formatMinutes(weeklyMinutes),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getTextColor(context),
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(width: 8),
                if (weeklyMinutes > 0)
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
            // 7-Day Trend Bar Chart
            _build7DayTrendChart(),
            const SizedBox(height: 16),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SESSIONS',
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
                          '$weeklySessionCount',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.getTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build7DayTrendChart() {
    final weekDates = _getWeekDates();
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Get max minutes for scaling
    int maxMinutes = 1;
    for (final date in weekDates) {
      final mins = _getMinutesForDate(date);
      if (mins > maxMinutes) maxMinutes = mins;
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
          final minutes = _getMinutesForDate(date);
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

  Widget _buildHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Detailed Ritual History',
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
                MaterialPageRoute(builder: (_) => const FullHistoryScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.getIconBgColor(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(
                    'All history',
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
    );
  }

  Widget _buildRitualHistory() {
    return const RitualHistoryList(limit: 5);
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  Widget _buildPerformanceInsight() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getSageColor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.getSageColor(context).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.getSageColor(context).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology,
                color: AppTheme.getSageColor(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance Insight',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _generateInsightMessage(),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getMutedColor(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _generateInsightMessage() {
    if (_userStats == null) return 'Start your journey to see insights here.';

    final minutesThisWeek = _userStats!.minutesThisWeek;
    final minutesLastWeek = _userStats!.minutesLastWeek;

    // Calculate percent change
    String trendPart = '';
    if (minutesLastWeek > 0) {
      final change =
          ((minutesThisWeek - minutesLastWeek) / minutesLastWeek) * 100;
      final isUp = change >= 0;
      trendPart =
          'Consistency is ${isUp ? 'up' : 'down'} by ${change.abs().toStringAsFixed(0)}% this week. ';
    } else if (minutesThisWeek > 0) {
      trendPart = 'Great start to the week! ';
    } else {
      trendPart = 'Complete a ritual to track your progress. ';
    }

    // Find peak day
    String dayPart = '';
    if (_weeklyCompletions.isNotEmpty) {
      String bestDay = '';
      int maxMinutes = -1;

      // We need to map dates to days of week to find "Tuesdays"
      // _weeklyCompletions keys are YYYY-MM-DD
      // We can iterate and group by weekday, but for simplicity let's just find the max day
      // and say "Your activity was highest on [Day]"

      _weeklyCompletions.forEach((dateStr, minutes) {
        if (minutes > maxMinutes) {
          maxMinutes = minutes;
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final date = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            bestDay = _getDayName(date.weekday);
          }
        }
      });

      if (maxMinutes > 0 && bestDay.isNotEmpty) {
        dayPart = 'Your activity peaked on $bestDay with $maxMinutes minutes.';
      } else {
        dayPart = 'Keep going to establish a daily rhythm.';
      }
    }

    return '$trendPart$dayPart';
  }

  Widget _buildWeeklyActivityHistory() {
    // Aggregate data by week (last 12 weeks)
    final Map<String, int> weeklyData = {};
    final Map<String, Map<String, int>> dailyDataByWeek = {};

    final now = DateTime.now();

    // Generate last 12 weeks
    for (int weekOffset = 0; weekOffset < 12; weekOffset++) {
      final weekStart = now.subtract(
        Duration(days: now.weekday - 1 + (weekOffset * 7)),
      );
      final weekKey = _getWeekKey(weekStart);

      int weekTotal = 0;
      final Map<String, int> weekDailyData = {};

      // Get data for each day in the week
      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dateKey = _formatDateKey(date);

        // Use _getMinutesForDate to ensure real-time data sync
        // especially important for the current week
        final minutes = _getMinutesForDate(date);

        if (minutes > 0) {
          weekTotal += minutes;
          weekDailyData[dateKey] = minutes;
        }
      }

      // Sync with UserStats for current week if available to ensure exact match with top card
      if (weekOffset == 0 &&
          _userStats != null &&
          _userStats!.minutesThisWeek > weekTotal) {
        // This handles cases where _weeklyCompletions might lag slightly behind userStats
        // However, since we populate chart from daily data, we should try to rely on daily data.
        // But if total mismatches, we trust userStats for the 'total' display usually.
        // Let's rely on the daily sum for now as per previous "Chart Sync" fix which worked well.
      }

      // Only include weeks with activity
      if (weekTotal > 0) {
        weeklyData[weekKey] = weekTotal;
        dailyDataByWeek[weekKey] = weekDailyData;
      }
    }

    if (weeklyData.isEmpty) {
      return const SizedBox.shrink();
    }

    return WeeklyActivityHistory(
      weeklyData: weeklyData,
      dailyDataByWeek: dailyDataByWeek,
      limit: 1, // Show only current week as requested
    );
  }

  String _getWeekKey(DateTime date) {
    // Calculate ISO week number
    final thursday = date.add(Duration(days: 3 - date.weekday));
    final year = thursday.year;
    final jan4 = DateTime(year, 1, 4);
    final weekNumber = ((thursday.difference(jan4).inDays + jan4.weekday) / 7)
        .ceil();

    return '${year}-W${weekNumber.toString().padLeft(2, '0')}';
  }
}
