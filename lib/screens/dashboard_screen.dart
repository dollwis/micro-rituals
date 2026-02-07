import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/meditation.dart';
import '../models/firestore_user.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/ritual_window_service.dart';

import 'breathing_session_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'zen_vault_screen.dart';
import 'saved_rituals_screen.dart';

import 'audio_player_screen.dart';
import '../widgets/mini_audio_player.dart';

/// Dashboard Home Screen - Redesigned to match reference UI
/// Features: Up Next card, 2x2 stats grid, recent rituals, bottom nav
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedNavIndex = 0;

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  FirestoreUser? _userStats;
  String? _streakIconUrl;
  int? _lastStreakForIcon;

  // Ritual Windows state
  Timer? _countdownTimer;
  Duration _timeUntilNextWindow = Duration.zero;
  bool _isWindowCompleted = false;

  // Quotes list
  final List<String> _quotes = [
    '"Peace comes from within. Do not seek it without." — Buddha',
    '"Quiet the mind, and the soul will speak." — Ma Jaya Sati Bhagavati',
    '"Meditation is not a way of making your mind quiet. It’s a way of entering into the quiet that’s already there." — Deepak Chopra',
    '"The soul always knows what to do to heal itself. The challenge is to silence the mind." — Caroline Myss',
    '"Inner peace begins the moment you choose not to allow another person or event to control your emotions." — Pema Chödrön',
    '"Feelings are just visitors; let them come and go." — Mooji',
    '"Your calm mind is the ultimate weapon against your challenges. So relax." — Bryant McGill',
    '"Meditation is essentially hanging out with your soul." — Unknown',
    '"To understand the immeasurable, the mind must be extraordinarily quiet, still." — Jiddu Krishnamurti',
    '"Empty your mind, be formless, shapeless—like water." — Bruce Lee',
  ];

  // Custom Notification State
  Meditation? _savedRitualNotification;
  Timer? _notificationTimer;

  late String _currentQuote;

  @override
  void initState() {
    super.initState();
    _currentQuote = (_quotes..shuffle()).first;
    _loadUserStats();
    _initRitualWindows();
    _fetchAndCacheMeditations();
  }

  // ... (existing code)

  Widget _buildQuoteCard() {
    return Container(
      // width: double.infinity, // Flexible width
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getSageColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        _currentQuote,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: AppTheme.getMutedColor(context),
          height: 1.4,
        ),
      ),
    );
  }

  Future<void> _fetchAndCacheMeditations() async {
    try {
      final meditations = await _firestoreService.getAllMeditations();
      RitualWindowService.cacheMeditations(meditations);
      if (mounted) {
        setState(() {
          // Trigger rebuild to update UI with cached meditations
        });
      }
    } catch (e) {
      debugPrint('Error fetching meditations: $e');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _initRitualWindows() {
    // Update countdown immediately
    _updateCountdown();

    // Check completion state
    _checkWindowCompletion();

    // Start periodic timer for countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final remaining = RitualWindowService.getTimeUntilNextWindow();

    // Check if we crossed into a new window
    if (remaining > _timeUntilNextWindow &&
        _timeUntilNextWindow != Duration.zero) {
      // New window started - reset completion state
      _checkWindowCompletion();
    }

    if (mounted) {
      setState(() {
        _timeUntilNextWindow = remaining;
      });
    }
  }

  Future<void> _checkWindowCompletion() async {
    final completed = await RitualWindowService.isCurrentWindowCompleted();
    if (mounted) {
      setState(() => _isWindowCompleted = completed);
    }
  }

  void _loadUserStats() {
    final uid = _authService.currentUserId;
    if (uid != null) {
      _firestoreService.streamUserStats(uid).listen((user) {
        if (mounted) {
          setState(() => _userStats = user);
          if (user != null) {
            _updateStreakIcon(user.currentStreak);
          }
        }
      });
      // Create user if doesn't exist
      _firestoreService.getOrCreateUser(uid);
    }
  }

  Future<void> _updateStreakIcon(int streak) async {
    // Avoid re-fetching if streak hasn't changed category or we already have the url for this streak
    // Actually, we just need to check if the filename would change.

    if (_lastStreakForIcon == streak && _streakIconUrl != null) return;

    String iconName;
    if (streak >= 7) {
      iconName = 'streak3.png';
    } else if (streak >= 4) {
      iconName = 'streak2.png';
    } else {
      iconName = 'streak1.png';
    }

    // Optimization: If we already have a URL and the iconName hasn't changed effectively (logic-wise),
    // but here we just check raw streak. Let's just fetch it.
    // To be safer/cleaner, we could map streak to iconName and check if that changed.

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'assets/icons/$iconName',
      );
      final url = await ref.getDownloadURL();
      if (mounted) {
        setState(() {
          _streakIconUrl = url;
          _lastStreakForIcon = streak;
        });
      }
    } catch (e) {
      debugPrint('Error loading streak icon: $e');
      // Fallback or keep null to show default icon
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      extendBody: true, // Allows content to scroll behind the nav bar
      body: Stack(
        children: [
          // Main Content
          IndexedStack(
            index: _selectedNavIndex,
            children: [
              _buildHomeContent(),
              const ZenVaultScreen(),
              const StatsScreen(),
              const SettingsScreen(),
            ],
          ),

          // Custom Saved Ritual Notification
          if (_savedRitualNotification != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100, // Above bottom nav
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.sageGreenDark,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Saved '${_savedRitualNotification!.title}' to collection",
                        style: const TextStyle(
                          color: AppTheme.primaryText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _notificationTimer?.cancel();
                        setState(() => _savedRitualNotification = null);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SavedRitualsScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'VIEW',
                        style: TextStyle(
                          color: AppTheme.primaryText,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [const MiniAudioPlayer(), _buildBottomNav()],
      ),
    );
  }

  Widget _buildHomeContent() {
    final currentRitual = RitualWindowService.getCurrentWindowRitual();
    final windowLabel = RitualWindowService.getCurrentWindowLabel();
    final now = DateTime.now();
    final dateString = _formatDate(now);

    return SafeArea(
      bottom: false, // Let content go behind nav bar
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // Space for nav bar
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(dateString),

            // Main content with padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Window specific card (Up Next)
                  if (currentRitual == null)
                    _buildNoRitualsCard()
                  else if (_isWindowCompleted)
                    _buildWellDoneCard(windowLabel)
                  else
                    _buildUpNextCard(currentRitual, windowLabel),

                  const SizedBox(height: 24),
                  _buildSectionHeader('DISCOVER'),
                  const SizedBox(height: 16),

                  // Horizontal List of Cards
                  StreamBuilder<List<Meditation>>(
                    stream: _firestoreService.streamMeditations(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          height: 280,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final meditations = snapshot.data!;
                      if (meditations.isEmpty) return const SizedBox.shrink();

                      // Filter for free/premium if needed, or show lock icon
                      // Logic: All can be seen, premium ones have lock if user is free.

                      return SizedBox(
                        height: 280,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none, // Allow shadows to overflow
                          itemCount: meditations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final meditation = meditations[index];
                            return _buildDiscoveryCard(meditation);
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  const SizedBox(height: 8),

                  // Insight & Quote Side-by-Side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildInsightCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuoteCard()),
                    ],
                  ),

                  const SizedBox(height: 40), // Bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSavedNotification(Meditation meditation) {
    _notificationTimer?.cancel();
    setState(() {
      _savedRitualNotification = meditation;
    });

    _notificationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _savedRitualNotification = null;
        });
      }
    });
  }

  // Removed _buildStreakCard() as per new design

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: AppTheme.getMutedColor(context),
      ),
    );
  }

  Widget _buildDiscoveryCard(Meditation data) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioPlayerScreen(meditation: data),
          ),
        );
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Cover Image
              if (data.coverImage.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: data.coverImage,
                  fit: BoxFit.cover,
                  memCacheWidth: 400, // Optimization
                  fadeInDuration: Duration.zero,
                  placeholder: (context, url) => Container(
                    color: AppTheme.getSageColor(
                      context,
                    ).withValues(alpha: 0.2),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppTheme.getSageColor(
                      context,
                    ).withValues(alpha: 0.2),
                    child: Icon(
                      Icons.spa,
                      color: AppTheme.getMutedColor(context),
                    ),
                  ),
                )
              else
                Container(
                  color: AppTheme.getSageColor(context).withValues(alpha: 0.2),
                  child: Icon(
                    Icons.spa,
                    size: 40,
                    color: AppTheme.getPrimary(context).withValues(alpha: 0.5),
                  ),
                ),

              // 2. Gradient Overlay (Bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 140,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Info Chips
              Positioned(
                bottom: 16,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Row for Category + Duration
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildCardInfoChip(data.category.toUpperCase()),
                        _buildCardInfoChip(data.formattedDuration),
                        Builder(
                          builder: (context) {
                            final isSaved =
                                _userStats?.listenLaterIds.contains(data.id) ??
                                false;
                            return GestureDetector(
                              onTap: () async {
                                final uid = _authService.currentUserId;
                                if (uid != null) {
                                  // Toggle logic
                                  await _firestoreService.toggleListenLater(
                                    uid,
                                    data.id,
                                    !isSaved,
                                  );
                                  if (mounted && !isSaved) {
                                    // Only show notification when adding
                                    _showSavedNotification(data);
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isSaved
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_add_outlined,
                                  size: 14,
                                  color: isSaved
                                      ? AppTheme.getPrimary(context)
                                      : Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Lock Icon for premium if needed
              if (data.isPremium && !(_userStats?.isSubscriber ?? false))
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInsightCard() {
    final minutesThisWeek = _userStats?.minutesThisWeek ?? 0;
    final minutesLastWeek = _userStats?.minutesLastWeek ?? 0;

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
                  ? Colors.white.withValues(alpha: 0.1)
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

  String _formatDate(DateTime date) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
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
    return '${days[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}';
  }

  Widget _buildHeader(String dateString) {
    // Get current time for greeting
    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 4 && hour < 12) {
      greeting = 'Good Morning';
    } else if (hour >= 12 && hour < 18) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    // Get user first name
    String userName = 'Friend';
    if (_userStats?.firstName != null && _userStats!.firstName!.isNotEmpty) {
      userName = _userStats!.firstName!;
    } else if (_userStats?.displayName != null &&
        _userStats!.displayName.isNotEmpty) {
      userName = _userStats!.displayName.split(' ').first;
    } else if (_authService.currentUser?.displayName != null) {
      userName = _authService.currentUser!.displayName!.split(' ').first;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        24, // Increased top padding for notch safety
        24,
        12,
      ), // Reduced top/bottom padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateString.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppTheme.getMutedColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$greeting, $userName',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.getTextColor(context),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          // Streak Icon Button (Top Right)
          if (_userStats != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 20,
                    color: AppTheme.getOrangeColor(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_userStats?.currentStreak ?? 0}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUpNextCard(Meditation ritual, String windowLabel) {
    final countdown = RitualWindowService.formatCountdown(_timeUntilNextWindow);

    return Container(
      width: double.infinity,
      height: 170, // Reduced from 240
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24), // Slightly smaller radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Image
            if (ritual.coverImage.isNotEmpty)
              CachedNetworkImage(
                imageUrl: ritual.coverImage,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                placeholder: (context, url) => Container(
                  color: AppTheme.sageGreenDark,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    Container(color: AppTheme.sageGreenDark),
              )
            else
              Container(color: AppTheme.sageGreenDark),

            // 2. Blur Effect
            if (ritual.coverImage.isNotEmpty)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.black.withValues(alpha: 0.2)),
              ),

            // 3. Gradient Overlay for Readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),

            // 4. Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          windowLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        '10 min',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  Text(
                    ritual.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    'Start your mindful practice',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'In: $countdown',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    BreathingSessionScreen(ritual: ritual),
                              ),
                            );
                            if (result == true || result == null) {
                              _checkWindowCompletion();
                            }
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppTheme.sageGreenDark,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Start',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.sageGreenDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildUpNextCardLegacy(Meditation ritual, String windowLabel) {
    final minutes = ritual.duration;
    final countdown = RitualWindowService.formatCountdown(_timeUntilNextWindow);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.getSageCardDecoration(context),
      child: Stack(
        children: [
          // Background blur circle
          Positioned(
            right: -32,
            top: -32,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.isDark(context)
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.sageGreenDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      windowLabel.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.sageGreenDark,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    '$minutes min',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.sageGreenDark.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                ritual.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.getTextColor(context),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start your mindful practice',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.getTextColor(context).withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Countdown Timer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.sageGreenDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: AppTheme.sageGreenDark.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Next Ritual in: $countdown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.sageGreenDark.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Start Button
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BreathingSessionScreen(ritual: ritual),
                    ),
                  );
                  // Mark window as completed when returning from session
                  if (result == true || result == null) {
                    // User completed or just returned - check if ritual was done
                    _checkWindowCompletion();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.sageGreenDark,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.sageGreenDark.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Start Ritual',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoRitualsCard() {
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

  Widget _buildWellDoneCard(String windowLabel) {
    final countdown = RitualWindowService.formatCountdown(_timeUntilNextWindow);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.sageGreen.withValues(alpha: 0.2),
            AppTheme.sageGreenDark.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.sageGreen.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Checkmark icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.sageGreenDark,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.sageGreenDark.withValues(alpha: 0.3),
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
            'Well Done! 🎉',
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

  Widget _buildBottomNav() {
    return Container(
      // Remove horizontal padding to let Expanded items fill the width
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.getBackground(context).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: AppTheme.getBorderColor(context)),
        ),
      ),
      child: Row(
        // Distribute space equally
        children: [
          _buildNavItem(Icons.grid_view_rounded, 'Home', 0),
          _buildNavItem(Icons.psychology_outlined, 'Reflect', 1),
          _buildNavItem(Icons.analytics_outlined, 'Stats', 2),
          _buildNavItem(Icons.settings_outlined, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedNavIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // Ensures the entire area is tappable
        onTap: () => setState(() => _selectedNavIndex = index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.getPrimary(context)
                  : AppTheme.getMutedColor(context).withValues(alpha: 0.4),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppTheme.getPrimary(context)
                    : AppTheme.getMutedColor(context).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
