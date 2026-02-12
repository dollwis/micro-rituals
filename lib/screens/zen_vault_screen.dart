import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/meditation.dart';
import '../models/firestore_user.dart';
import '../services/content_access_service.dart';
import '../services/rewarded_ad_service.dart';
import '../providers/user_stats_provider.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'audio_player_screen.dart';
import 'package:provider/provider.dart';
import '../providers/user_stats_provider.dart';
import 'subscription_screen.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/meditation_card.dart';

/// Zen Vault Screen - Meditation Library
/// Displays meditation cards with subscription gating
class ZenVaultScreen extends StatefulWidget {
  const ZenVaultScreen({super.key});

  @override
  State<ZenVaultScreen> createState() => _ZenVaultScreenState();
}

class _ZenVaultScreenState extends State<ZenVaultScreen> {
  // User stats for subscription check
  FirestoreUser? _userStats;

  // Computed property for subscription status
  bool get _isSubscriber => _userStats?.hasActiveSubscription ?? false;

  final ValueNotifier<String> _selectedCategory = ValueNotifier('All');

  // Rewarded ad service
  final RewardedAdService _adService = RewardedAdService();
  final ValueNotifier<bool> _isLoadingAd = ValueNotifier(false);

  // Search State
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _adService.initialize();
    _adService.loadRewardedAd();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _isLoadingAd.dispose();
    _selectedCategory.dispose();
    super.dispose();
  }

  Future<void> _onMeditationTap(
    Meditation meditation,
    List<Meditation> playlist,
  ) async {
    // Check access using ContentAccessService
    final accessResult = await ContentAccessService.canAccess(
      sessionId: meditation.id,
      isPremiumContent: meditation.isPremium,
      isAdRequired: meditation.isAdRequired,
      isSubscriber: _isSubscriber,
    );

    if (accessResult.canAccess) {
      _openAudioPlayer(meditation, playlist);
    } else if (accessResult.accessType == AccessType.premiumLocked) {
      _showPaywall();
    } else if (accessResult.accessType == AccessType.adLocked ||
        (meditation.isAdRequired && !_isSubscriber)) {
      _showRewardedAdPrompt(meditation, playlist);
    }
  }

  void _showPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SubscriptionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _showRewardedAdPrompt(Meditation meditation, List<Meditation> playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAdPromptSheet(meditation, playlist),
    );
  }

  Future<void> _watchAdToUnlock(
    Meditation meditation,
    List<Meditation> playlist,
  ) async {
    Navigator.pop(context); // Close the prompt

    // ✅ No setState - only update ValueNotifier
    _isLoadingAd.value = true;

    await _adService.showRewardedAd(
      onRewardGranted: () async {
        await ContentAccessService.unlockViaReward(meditation.id);
        if (mounted) {
          _isLoadingAd.value = false;
          // Show success and open the session
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unlocked ${meditation.title} for 24 hours!'),
              backgroundColor: AppTheme.sageGreenDark,
            ),
          );
          _openAudioPlayer(meditation, playlist);
        }
      },
      onAdDismissed: () {
        if (mounted) _isLoadingAd.value = false;
      },
      onAdFailed: (error) {
        if (mounted) {
          _isLoadingAd.value = false;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ad failed: $error')));
        }
      },
    );
  }

  Widget _buildAdPromptSheet(Meditation meditation, List<Meditation> playlist) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.getBorderColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.getSageColor(context).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.play_circle_outline,
              size: 32,
              color: AppTheme.getPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock ${meditation.title}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.getTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Watch a short video to unlock this session for 24 hours',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.getMutedColor(context),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _watchAdToUnlock(meditation, playlist),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.sageGreenDark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Watch Video',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _openAudioPlayer(Meditation meditation, List<Meditation> playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AudioPlayerScreen(meditation: meditation, playlist: playlist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Consumer<UserStatsProvider>(
          builder: (context, userStatsProvider, child) {
            final user = userStatsProvider.userStats;
            _userStats = user; // Assign for subscription checks
            final favoriteIds = user?.favoriteIds ?? [];

            return ValueListenableBuilder<String>(
              valueListenable: _selectedCategory,
              builder: (context, selectedCategory, child) {
                return StreamBuilder<List<Meditation>>(
                  stream: FirestoreService().streamMeditations(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final meditations = snapshot.data!;
                    List<Meditation> filteredMeditations;

                    // 1. Filter by Category
                    if (selectedCategory == 'All') {
                      filteredMeditations = meditations;
                    } else if (selectedCategory == 'Favorites') {
                      filteredMeditations = meditations
                          .where((m) => favoriteIds.contains(m.id))
                          .toList();
                    } else if (selectedCategory == 'Saved') {
                      final listenLaterIds = user?.listenLaterIds ?? [];
                      filteredMeditations = meditations
                          .where((m) => listenLaterIds.contains(m.id))
                          .toList();
                    } else {
                      filteredMeditations = meditations
                          .where(
                            (m) =>
                                m.category.toLowerCase() ==
                                selectedCategory.toLowerCase(),
                          )
                          .toList();
                    }

                    // 2. Filter by Search Query
                    if (_searchQuery.isNotEmpty) {
                      filteredMeditations = filteredMeditations
                          .where(
                            (m) => m.title.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                          )
                          .toList();
                    }

                    return SafeArea(
                      bottom: false,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header (Searchable)
                            _buildHeader(),
                            const SizedBox(height: 24),

                            // Category Chips
                            _buildCategoryFilter(),
                            const SizedBox(height: 24),

                            // Empty State
                            if (filteredMeditations.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 32,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: AppTheme.getMutedColor(context),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        selectedCategory == 'Saved'
                                            ? 'No saved rituals yet'
                                            : 'No meditations found',
                                        style: TextStyle(
                                          color: AppTheme.getMutedColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Meditation Cards
                            ...filteredMeditations.map(
                              (m) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildMeditationCard(
                                  m,
                                  favoriteIds.contains(m.id),
                                  user?.listenLaterIds.contains(m.id) ?? false,
                                  filteredMeditations,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        if (_isLoadingAd.value)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Push to edges
      children: [
        Expanded(
          child: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: TextStyle(
                    color: AppTheme.getTextColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by title...',
                    hintStyle: TextStyle(
                      color: AppTheme.getMutedColor(context),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zen Vault',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.getTextColor(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Explore your mind with peaceful meditations',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.getMutedColor(context),
                      ),
                    ),
                  ],
                ),
        ),
        // Search Toggle Icon
        IconButton(
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = '';
                _searchController.clear();
              }
            });
          },
          icon: Icon(
            _isSearching ? Icons.close : Icons.search, // Standard search icon
            size: 28,
            color: AppTheme.getTextColor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['All', 'Saved', 'Favorites', ...Meditation.categories];

    return ValueListenableBuilder<String>(
      valueListenable: _selectedCategory,
      builder: (context, selectedCategory, child) {
        return CategoryFilterChips(
          selectedCategory: selectedCategory,
          categories: categories,
          onCategorySelected: (category) {
            _selectedCategory.value = category;
          },
        );
      },
    );
  }

  void _toggleFavorite(String meditationId) {
    final uid = AuthService().currentUserId;
    if (uid != null) {
      final userStats = context.read<UserStatsProvider>().userStats;
      final isFavorite = userStats?.favoriteIds.contains(meditationId) ?? false;
      FirestoreService().toggleFavorite(uid, meditationId, !isFavorite);
    }
  }

  void _toggleSave(String meditationId) {
    final uid = AuthService().currentUserId;
    if (uid != null) {
      final userStats = context.read<UserStatsProvider>().userStats;
      final isSaved = userStats?.listenLaterIds.contains(meditationId) ?? false;
      FirestoreService().toggleListenLater(uid, meditationId, !isSaved);
    }
  }

  Widget _buildMeditationCard(
    Meditation meditation,
    bool isFavorite,
    bool isSaved,
    List<Meditation> playlist,
  ) {
    final isEvergreen = ContentAccessService.isEvergreen(meditation.id);

    return FutureBuilder<AccessResult>(
      future: ContentAccessService.canAccess(
        sessionId: meditation.id,
        isPremiumContent: meditation.isPremium,
        isAdRequired: meditation.isAdRequired,
        isSubscriber: _isSubscriber,
      ),
      builder: (context, snapshot) {
        final accessResult = snapshot.data;
        final accessType =
            accessResult?.accessType ??
            (isEvergreen
                ? AccessType.evergreenFree
                : (meditation.isAdRequired
                      ? AccessType.adLocked
                      : AccessType.adLocked));

        return MeditationCard(
          meditation: meditation,
          variant: MeditationCardVariant.full,
          isFavorite: isFavorite,
          isSaved: isSaved,
          showAccessBadge: true,
          accessBadge: _buildAccessBadge(
            accessType,
            accessResult?.remainingUnlockTime,
          ),
          isLocked: accessType == AccessType.premiumLocked,
          onTap: () => _onMeditationTap(meditation, playlist),
          onFavoriteToggle: () => _toggleFavorite(meditation.id),
          onSaveToggle: () => _toggleSave(meditation.id),
          getCategoryIcon: _getCategoryIcon,
          getCategoryColors: _getCategoryColors,
        );
      },
    );
  }

  Widget _buildAccessBadge(AccessType accessType, Duration? remainingTime) {
    String text;
    Color bgColor;
    Color textColor;
    IconData? icon;

    switch (accessType) {
      case AccessType.free:
      case AccessType.evergreenFree:
        return const SizedBox.shrink();
      case AccessType.adUnlocked:
        // Hide timer for subscribers
        if (_isSubscriber) return const SizedBox.shrink();
        final hours = remainingTime?.inHours ?? 0;
        final minutes = (remainingTime?.inMinutes ?? 0) % 60;
        text = '${hours}h ${minutes}m';
        bgColor = Colors.orange.withValues(alpha: 0.15);
        textColor = Colors.orange.shade700;
        icon = Icons.timer;
        break;
      case AccessType.adLocked:
        // Hide AD badge for subscribers
        if (_isSubscriber) return const SizedBox.shrink();
        text = 'AD';
        bgColor = Colors.blue.withValues(alpha: 0.15);
        textColor = Colors.blue.shade700;
        icon = Icons.videocam;
        break;
      case AccessType.premiumLocked:
        text = 'PRO';
        bgColor = const Color(0xFF9C27B0); // Bright Purple
        textColor = Colors.white;
        icon = Icons.star;
        break;
      case AccessType.subscriber:
        return const SizedBox.shrink(); // No badge needed
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getCategoryColors(String category) {
    switch (category) {
      case 'Sleep':
        return [const Color(0xFF5B4B8A), const Color(0xFF7B68A6)];
      case 'Focus':
        return [const Color(0xFF4A90A4), const Color(0xFF6BB3C9)];
      case 'Relax':
        return [const Color(0xFFAAD0CE), const Color(0xFF88B7B5)];
      case 'Nature':
        return [const Color(0xFF588157), const Color(0xFFA3B18A)];
      default:
        return [AppTheme.sageGreen, AppTheme.sageGreenDark];
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Sleep':
        return Icons.bedtime;
      case 'Focus':
        return Icons.center_focus_strong;
      case 'Relax':
        return Icons.spa;
      case 'Nature':
        return Icons.landscape;
      default:
        return Icons.self_improvement;
    }
  }
}
