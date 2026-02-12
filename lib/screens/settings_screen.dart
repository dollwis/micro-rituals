import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'subscription_screen.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/firestore_user.dart';
import '../models/notification_types.dart';

import '../screens/login_screen.dart';
import '../widgets/ritual_time_slider.dart';
import '../providers/theme_provider.dart';
import 'contact_support_screen.dart';
import 'profile_settings_screen.dart';
import 'admin_upload_screen.dart';
import '../providers/audio_player_provider.dart';
import 'privacy_policy_screen.dart';
import 'downloads_screen.dart';
import '../services/offline_mode_service.dart';

/// Comprehensive Settings Screen
/// Features: Profile header, stats cards, settings menu, account actions
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Import notification preferences
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  // States
  bool _notificationsEnabled = false;
  // Granular notification states
  bool _morningEnabled = true;
  bool _afternoonEnabled = true;
  bool _eveningEnabled = true;

  // Custom notification times
  TimeOfDay _morningTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _afternoonTime = const TimeOfDay(hour: 14, minute: 0);
  TimeOfDay _eveningTime = const TimeOfDay(hour: 20, minute: 0);

  bool _hasUnsavedChanges = false;
  // _reminderTime removed
  // _notificationTiming removed
  bool _showRitualWindowSettings = false;
  bool _isLoading = true;

  FirestoreUser? _userStats;

  // Real user data from Firebase Auth
  String get _userName =>
      _userStats?.displayName ??
      _authService.currentUser?.displayName ??
      'Mindful User';
  String get _userEmail =>
      _authService.currentUser?.email ?? 'user@dailypulse.app';
  String? get _userPhotoUrl =>
      _userStats?.photoUrl ?? _authService.currentUser?.photoURL;
  int get _totalCompleted => _userStats?.totalCompleted ?? 0;
  String get _subscriptionPlan =>
      (_userStats?.isSubscriber ?? false) ? 'Premium' : 'Free';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserStats();
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

  Future<void> _loadSettings() async {
    final prefs = await _notificationService.getNotificationPreferences();

    setState(() {
      _notificationsEnabled = prefs.enabled;

      _morningEnabled = prefs.morningEnabled;
      _afternoonEnabled = prefs.afternoonEnabled;
      _eveningEnabled = prefs.eveningEnabled;

      _morningTime = prefs.morningTime;
      _afternoonTime = prefs.afternoonTime;
      _eveningTime = prefs.eveningTime;

      // _notificationTiming removed
      _isLoading = false;
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _saveNotificationSettings() async {
    setState(() => _isLoading = true);
    try {
      final current = await _notificationService.getNotificationPreferences();
      final newPrefs = current.copyWith(
        morningEnabled: _morningEnabled,
        morningTime: _morningTime,
        afternoonEnabled: _afternoonEnabled,
        afternoonTime: _afternoonTime,
        eveningEnabled: _eveningEnabled,
        eveningTime: _eveningTime,
      );
      await _notificationService.setNotificationPreferences(newPrefs);

      if (mounted) {
        setState(() {
          _hasUnsavedChanges = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification settings saved'),
            backgroundColor: AppTheme.getSageColor(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // 1. Show Agreement Dialog
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.getCardColor(context),
          title: Text(
            'Enable Notifications?',
            style: TextStyle(color: AppTheme.getTextColor(context)),
          ),
          content: Text(
            'We use notifications to remind you of your daily micro-rituals. We promise not to spam you.',
            style: TextStyle(color: AppTheme.getTextColor(context)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.getMutedColor(context)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Allow',
                style: TextStyle(
                  color: AppTheme.getPrimary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;

      // 2. Request System Permission
      final granted = await _notificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable notifications in system settings'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    // Save new preferences
    final currentPrefs = await _notificationService
        .getNotificationPreferences();
    final updatedPrefs = currentPrefs.copyWith(
      enabled: value,
      timing: NotificationTiming.ritualWindows, // Force ritual windows
    );
    await _notificationService.setNotificationPreferences(updatedPrefs);
    setState(() => _notificationsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Settings',
          style: TextStyle(
            color: AppTheme.getTextColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Section
                  _buildProfileHeader(),
                  const SizedBox(height: 24),

                  // 2. Progress Stats
                  _buildStatsRow(),
                  const SizedBox(height: 32),

                  // 3. Settings List
                  _buildSectionHeader('PREFERENCES'),
                  const SizedBox(height: 12),
                  _buildDailyReminderTile(),
                  const SizedBox(height: 12),

                  // Ritual Window Times
                  _buildRitualWindowSection(),
                  const SizedBox(height: 12),

                  // Downloads
                  _buildDownloadsTile(),
                  const SizedBox(height: 12),

                  // New Theme Selector
                  _buildThemeSection(),
                  const SizedBox(height: 24),

                  _buildSectionHeader('SUBSCRIPTION'),
                  const SizedBox(height: 12),
                  _buildSubscriptionTile(),
                  const SizedBox(height: 24),

                  _buildSectionHeader('SUPPORT'),
                  const SizedBox(height: 12),
                  _buildSupportTile(),
                  const SizedBox(height: 12),

                  // Admin Section (Hidden)
                  if (_authService.currentUserId ==
                      '7Mg66gFuJvOBMwKHe4MkeD866qR2') ...[
                    _buildSectionHeader('ADMIN'),
                    const SizedBox(height: 12),
                    _buildAdminTile(),
                    const SizedBox(height: 12),

                    // Test Notification (Debug) - Moved to Admin
                    _buildListItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Test Notification (5s delay)',
                      onTap: () async {
                        await _notificationService.sendTestNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Notification scheduled for 5s from now',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      iconColor: Colors.orange,
                    ),
                    const SizedBox(height: 12),

                    const SizedBox(height: 32),
                  ],

                  // 4. Account Actions
                  _buildAccountActions(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. HEADER SECTION
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.transparent, // Hit test
        child: Row(
          children: [
            // Avatar with soft shadow
            Hero(
              tag: 'profile_pic',
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.sageGreen.withValues(alpha: 0.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.sageGreen.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: (_userStats?.isSubscriber ?? false)
                        ? const Color(0xFFFFD700) // Gold
                        : AppTheme.sageGreen,
                    width: 2.5,
                  ),
                  image: _userPhotoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_userPhotoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _userPhotoUrl == null
                    ? Icon(
                        Icons.person,
                        color: AppTheme.getPrimary(context),
                        size: 32,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),

            // Name & Email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getTextColor(context),
                    ),
                  ),
                  Text(
                    _userEmail,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.getMutedColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Streak Badge moved to Reflection Screen
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. STATS CARDS WITH GLASSMORPHISM
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final minutesOfCalm = _userStats?.totalMinutes ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildGlassCard(
            'Total Rituals',
            '$_totalCompleted',
            Icons.spa,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassCard(
            'Minutes of Calm',
            '$minutesOfCalm',
            Icons.timer_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard(String title, String value, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppTheme.isDark(context)
                  ? [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.02),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.4),
                      Colors.white.withValues(alpha: 0.1),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.isDark(context)
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.getSageColor(context).withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.getSageColor(context), size: 24),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.getTextColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.getMutedColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. SETTINGS LIST
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.getMutedColor(context),
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildDailyReminderTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        children: [
          // Toggle row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.getSageColor(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: AppTheme.getPrimary(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Reminder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getTextColor(context),
                      ),
                    ),
                    Text(
                      'Enable daily notifications',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.getMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
                activeTrackColor: AppTheme.getPrimary(context),
                thumbColor: WidgetStateProperty.all(Colors.white),
              ),
            ],
          ),

          // Time picker removed as per user request
        ],
      ),
    );
  }

  Widget _buildThemeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.getTextColor(context),
            ),
          ),
          const SizedBox(height: 16),
          // Theme Options Row
          Row(
            children: [
              _buildThemeOption(
                name: 'Lavender',
                variant: ThemeVariant.lavender,
                color: const Color(0xFF7B6F93),
              ),
              const SizedBox(width: 12),
              _buildThemeOption(
                name: 'Sunrise',
                variant: ThemeVariant.sunrise,
                color: const Color(0xFFD48C70),
              ),
              const SizedBox(width: 12),
              _buildThemeOption(
                name: 'Ocean',
                variant: ThemeVariant.ocean,
                color: const Color(0xFF5DA7B1),
              ),
              const SizedBox(width: 12),
              _buildThemeOption(
                name: 'Sage',
                variant: ThemeVariant.sage,
                color: const Color(0xFF7A8266),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: AppTheme.getBorderColor(context), height: 1),
          const SizedBox(height: 16),
          // Dark Mode Toggle
          _buildZenModeToggle(),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String name,
    required ThemeVariant variant,
    required Color color,
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    final isSelected = themeProvider.currentVariant == variant;

    return Expanded(
      child: GestureDetector(
        onTap: () => themeProvider.setVariant(variant),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppTheme.getBorderColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.getTextColor(context)
                      : AppTheme.getMutedColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZenModeToggle() {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (isDark ? Colors.indigo : Colors.orange).withValues(
              alpha: 0.1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: isDark ? Colors.indigo : Colors.orange,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextColor(context),
                ),
              ),
              Text(
                isDark ? 'Zen Mode (Dark)' : 'Daylight Mode (Light)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.getMutedColor(context),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: isDark,
          onChanged: (value) => themeProvider.toggleTheme(value),
          activeTrackColor: AppTheme.getPrimary(context),
          thumbColor: WidgetStateProperty.all(Colors.white),
        ),
      ],
    );
  }

  Widget _buildDownloadsTile() {
    return FutureBuilder<int>(
      future: OfflineModeService().getDownloadedIds().then((ids) => ids.length),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return _buildListItem(
          icon: Icons.download_rounded,
          title: count > 0 ? 'Offline Downloads ($count)' : 'Offline Downloads',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DownloadsScreen()),
            );
          },
        );
      },
    );
  }

  Widget _buildSubscriptionTile() {
    final isPremium = _subscriptionPlan == 'Premium';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPremium
                      ? Colors.amber.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPremium ? Icons.workspace_premium : Icons.star_outline,
                  color: isPremium ? Colors.amber : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getTextColor(context),
                      ),
                    ),
                    Text(
                      'Plan: $_subscriptionPlan',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.getMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isPremium) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Days Left',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getMutedColor(context),
                        ),
                      ),
                      Text(
                        '${_userStats?.subscriptionExpiry?.difference(DateTime.now()).inDays ?? 0} Days',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Thank you! 💖',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.getPrimary(context),
                      AppTheme.getPrimary(context).withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.getPrimary(
                        context,
                      ).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        children: [
          _buildListItem(
            icon: Icons.shield_outlined,
            title: 'Privacy Policy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
          Divider(color: AppTheme.getBorderColor(context), height: 24),
          _buildListItem(
            icon: Icons.help_outline,
            title: 'Contact Support',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContactSupportScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? AppTheme.getMutedColor(context),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.getTextColor(context),
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppTheme.getMutedColor(context),
            size: 20,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. ACCOUNT ACTIONS
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildAccountActions() {
    return Column(
      children: [
        // Log Out button
        GestureDetector(
          onTap: () async {
            // Stop audio before signing out
            if (mounted) {
              await context.read<AudioPlayerProvider>().stop();
            }
            await _authService.signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.getIconBgColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getMutedColor(context),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAdminTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: _buildListItem(
        icon: Icons.admin_panel_settings,
        title: 'Upload Ritual',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // RITUAL WINDOW SETTINGS SECTION
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildRitualWindowSection() {
    // Only show if master notifications are enabled
    if (!_notificationsEnabled) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        children: [
          // Header with expand/collapse
          InkWell(
            onTap: () {
              setState(
                () => _showRitualWindowSettings = !_showRitualWindowSettings,
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.getSageColor(
                        context,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: AppTheme.getPrimary(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ritual Notifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.getTextColor(context),
                          ),
                        ),
                        Text(
                          'Customize which rituals to be notified for',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.getMutedColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showRitualWindowSettings
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.getMutedColor(context),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (_showRitualWindowSettings) ...[
            Divider(color: AppTheme.getBorderColor(context), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Morning Window
                  _buildWindowToggle(
                    icon: Icons.wb_sunny,
                    iconColor: Colors.orange,
                    label: 'Morning Ritual',
                    subLabel: 'Window: 04:00 - 12:00',
                    value: _morningEnabled,
                    time: _morningTime,
                    startTime: const TimeOfDay(hour: 4, minute: 0),
                    endTime: const TimeOfDay(hour: 12, minute: 0),
                    onChanged: (val) {
                      setState(() {
                        _morningEnabled = val;
                        _hasUnsavedChanges = true;
                      });
                    },
                    onTimeChanged: (newTime) {
                      setState(() {
                        _morningTime = newTime;
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Afternoon Window
                  _buildWindowToggle(
                    icon: Icons.wb_cloudy,
                    iconColor: Colors.blue,
                    label: 'Afternoon Reset',
                    subLabel: 'Window: 12:00 - 18:00',
                    value: _afternoonEnabled,
                    time: _afternoonTime,
                    startTime: const TimeOfDay(hour: 12, minute: 0),
                    endTime: const TimeOfDay(hour: 18, minute: 0),
                    onChanged: (val) {
                      setState(() {
                        _afternoonEnabled = val;
                        _hasUnsavedChanges = true;
                      });
                    },
                    onTimeChanged: (newTime) {
                      setState(() {
                        _afternoonTime = newTime;
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Evening Window
                  _buildWindowToggle(
                    icon: Icons.nights_stay,
                    iconColor: Colors.indigo,
                    label: 'Evening Wind-Down',
                    subLabel: 'Window: 18:00 - 04:00',
                    value: _eveningEnabled,
                    time: _eveningTime,
                    startTime: const TimeOfDay(hour: 18, minute: 0),
                    endTime: const TimeOfDay(hour: 4, minute: 0),
                    onChanged: (val) {
                      setState(() {
                        _eveningEnabled = val;
                        _hasUnsavedChanges = true;
                      });
                    },
                    onTimeChanged: (newTime) {
                      setState(() {
                        _eveningTime = newTime;
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),

                  // Action Buttons
                  if (_hasUnsavedChanges) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Discard changes by reloading
                            _loadSettings();
                          },
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppTheme.getMutedColor(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : _saveNotificationSettings,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check, size: 16),
                          label: const Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.getPrimary(context),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWindowToggle({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subLabel,
    required bool value,
    required ValueChanged<bool> onChanged,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onTimeChanged,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.getSageColor(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.getTextColor(context),
                      ),
                    ),
                    Text(
                      subLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getMutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppTheme.getPrimary(context),
                thumbColor: WidgetStateProperty.all(Colors.white),
              ),
            ],
          ),
          if (value) ...[
            const SizedBox(height: 12),
            RitualTimeSlider(
              startTime: startTime,
              endTime: endTime,
              currentTime: time,
              onChanged: onTimeChanged,
              isEnabled: value,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
