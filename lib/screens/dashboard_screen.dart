import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/meditation.dart';
import '../models/firestore_user.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/ritual_window_service.dart';

import 'stats_screen.dart';
import 'settings_screen.dart';
import 'zen_vault_screen.dart';
import 'saved_rituals_screen.dart';

import 'audio_player_screen.dart';
import '../widgets/mini_audio_player.dart';

import '../widgets/dashboard_insight_card.dart';
import '../widgets/dashboard_well_done_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_up_next_card.dart';
import '../widgets/dashboard_discovery_card.dart';
// import '../widgets/dashboard_waiting_card.dart';
import '../widgets/daily_progress_panel.dart';

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
  StreamSubscription<FirestoreUser?>? _userStatsSubscription;
  String? _streakIconUrl;
  int? _lastStreakForIcon;

  // Ritual State (Async Loading)
  Meditation? _currentRitual;
  String _currentWindowLabel = '';
  String _nextWindowLabel = ''; // For waiting card
  bool _isLoadingRitual = true;

  // Ritual Windows state
  Timer? _countdownTimer;
  final ValueNotifier<Duration> _timeUntilNextWindow = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<bool> _isWindowCompleted = ValueNotifier(false);

  // Daily Progress Status
  Map<int, String> _dailyStatuses = {};

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
    _refreshRitualState();
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
    } finally {
      // Ensure we refresh the state after fetching, even if it failed or cache was used
      if (mounted) {
        _refreshRitualState();
      }
    }
  }

  @override
  void dispose() {
    _userStatsSubscription?.cancel();
    _countdownTimer?.cancel();
    _notificationTimer?.cancel();
    _timeUntilNextWindow.dispose();
    _isWindowCompleted.dispose();
    super.dispose();
  }

  void _initRitualWindows() {
    // Update countdown immediately
    _updateCountdown();

    // Check completion state
    _checkWindowCompletion();

    // Start periodic timer for countdown and state refresh
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
      // Periodically refresh state in case window changes (e.g. time passes)
      // Check every minute or so would be better, but we can do a check:
      if (DateTime.now().second == 0) {
        _refreshRitualState();
      }
    });
  }

  Future<void> _refreshRitualState() async {
    // Try to get current ritual
    var ritual = await RitualWindowService.getCurrentWindowRitual();
    var label = await RitualWindowService.getCurrentWindowLabel();

    String nextLabel = '';

    // If no active ritual (waiting), get the NEXT one and show it immediately
    if (ritual == null) {
      ritual = await RitualWindowService.getNextWindowRitual();
      // Update label to show what's coming (or we could keep it as "Next Ritual")
      // But user wants to see it "Open", so maybe use the actual label of that window?
      nextLabel = await RitualWindowService.getNextWindowLabel();
      if (ritual != null) {
        // If we found a next ritual, use its window label
        // We can derive it or just use nextLabel
        label = nextLabel;
      }
    } else {
      // If currently active, next label logic remains
      // (Though usually we only need nextLabel for the WaitingCard which we are removing)
    }

    // Also refresh daily statuses
    final statuses = await RitualWindowService.getDailyWindowStatuses(
      DateTime.now(),
    );

    if (mounted) {
      if (_currentRitual != ritual ||
          _currentWindowLabel != label ||
          _nextWindowLabel != nextLabel ||
          _dailyStatuses != statuses) {
        setState(() {
          _currentRitual = ritual;
          _currentWindowLabel = label;
          _nextWindowLabel = nextLabel;
          _dailyStatuses = statuses;
          _isLoadingRitual = false;
        });
      } else {
        // Just update loading state if needed
        if (_isLoadingRitual) {
          setState(() => _isLoadingRitual = false);
        }
      }
    }
  }

  void _updateCountdown() async {
    // Use custom notification window times instead of fixed 4-hour windows
    final remaining =
        await RitualWindowService.getTimeUntilNextNotificationWindow();

    // Check if we crossed into a new window
    if (remaining > _timeUntilNextWindow.value &&
        _timeUntilNextWindow.value != Duration.zero) {
      // New window started - reset completion state
      // New window started - reset completion state & refresh ritual
      _checkWindowCompletion();
      _refreshRitualState();
    }

    // ✅ No setState - only update ValueNotifier
    _timeUntilNextWindow.value = remaining;
  }

  Future<void> _checkWindowCompletion() async {
    final completed = await RitualWindowService.isCurrentWindowCompleted();
    // ✅ No setState - only update ValueNotifier
    _isWindowCompleted.value = completed;
  }

  void _loadUserStats() {
    final uid = _authService.currentUserId;
    if (uid != null) {
      _userStatsSubscription?.cancel();
      _userStatsSubscription = _firestoreService.streamUserStats(uid).listen((
        user,
      ) {
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
    // Use state variables instead of synchronous calls
    final currentRitual = _currentRitual;
    final windowLabel = _currentWindowLabel;
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
            DashboardHeader(
              dateString: dateString,
              userStats: _userStats,
              currentUser: _authService.currentUser,
            ),

            // Main content with padding
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Window specific card (Up Next)
                  if (_isLoadingRitual)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  // Removed DashboardWaitingCard - we now show the ritual immediately
                  else if (_isWindowCompleted.value)
                    Column(
                      children: [
                        DashboardWellDoneCard(
                          windowLabel: windowLabel,
                          timeUntilNextWindow: _timeUntilNextWindow.value,
                        ),
                        const SizedBox(height: 16),
                        DailyProgressPanel(statuses: _dailyStatuses),
                      ],
                    )
                  else if (currentRitual != null)
                    Column(
                      children: [
                        DashboardUpNextCard(
                          ritual: currentRitual,
                          windowLabel: windowLabel,
                          timeUntilNextWindow: _timeUntilNextWindow.value,
                          onCheckWindowCompletion: _checkWindowCompletion,
                        ),
                        const SizedBox(height: 16),
                        DailyProgressPanel(statuses: _dailyStatuses),
                      ],
                    ),

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
                      Expanded(
                        child: DashboardInsightCard(
                          minutesThisWeek: _userStats?.minutesThisWeek ?? 0,
                          minutesLastWeek: _userStats?.minutesLastWeek ?? 0,
                        ),
                      ),
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
    final isSaved = _userStats?.listenLaterIds.contains(data.id) ?? false;

    return DashboardDiscoveryCard(
      meditation: data,
      isSaved: isSaved,
      onSave: () async {
        final uid = _authService.currentUserId;
        if (uid == null) return;

        await _firestoreService.toggleListenLater(uid, data.id, !isSaved);

        // Show notification when saving
        if (!isSaved && mounted) {
          _showSavedNotification(data);
        }
      },
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioPlayerScreen(meditation: data),
          ),
        );
      },
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
          _buildNavItem(Icons.library_music_outlined, 'Zen Vault', 1),
          _buildNavItem(Icons.analytics_outlined, 'Stats', 2),
          _buildNavItem(Icons.settings_outlined, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedNavIndex == index;
    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: isSelected,
        hint: isSelected
            ? '$label tab, currently selected'
            : 'Double tap to switch to $label tab',
        child: GestureDetector(
          behavior:
              HitTestBehavior.opaque, // Ensures the entire area is tappable
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
      ),
    );
  }
}
