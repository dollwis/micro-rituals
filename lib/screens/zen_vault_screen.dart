import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/meditation.dart';
import '../services/content_access_service.dart';
import '../services/rewarded_ad_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/firestore_user.dart';
import 'audio_player_screen.dart';
import 'package:provider/provider.dart';
import '../providers/audio_player_provider.dart';

/// Zen Vault Screen - Meditation Library
/// Displays meditation cards with subscription gating
class ZenVaultScreen extends StatefulWidget {
  const ZenVaultScreen({super.key});

  @override
  State<ZenVaultScreen> createState() => _ZenVaultScreenState();
}

class _ZenVaultScreenState extends State<ZenVaultScreen> {
  // Mock subscription status (would come from Firebase in production)
  final bool _isSubscriber = false;
  String _selectedCategory = 'All';

  // Rewarded ad service
  final RewardedAdService _adService = RewardedAdService();
  bool _isLoadingAd = false;

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPaywallSheet(),
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

    setState(() => _isLoadingAd = true);

    await _adService.showRewardedAd(
      onRewardGranted: () async {
        await ContentAccessService.unlockViaReward(meditation.id);
        if (mounted) {
          setState(() => _isLoadingAd = false);
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
        if (mounted) setState(() => _isLoadingAd = false);
      },
      onAdFailed: (error) {
        if (mounted) {
          setState(() => _isLoadingAd = false);
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
    final uid = AuthService().currentUserId;

    return Stack(
      children: [
        StreamBuilder<FirestoreUser?>(
          stream: uid != null
              ? FirestoreService().streamUserStats(uid)
              : Stream.value(null),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data;
            final favoriteIds = user?.favoriteIds ?? [];

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
                if (_selectedCategory == 'All') {
                  filteredMeditations = meditations;
                } else if (_selectedCategory == 'Favorites') {
                  filteredMeditations = meditations
                      .where((m) => favoriteIds.contains(m.id))
                      .toList();
                } else if (_selectedCategory == 'Saved') {
                  final listenLaterIds = user?.listenLaterIds ?? [];
                  filteredMeditations = meditations
                      .where((m) => listenLaterIds.contains(m.id))
                      .toList();
                } else {
                  filteredMeditations = meditations
                      .where((m) => m.category == _selectedCategory)
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
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: AppTheme.getMutedColor(context),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedCategory == 'Saved'
                                        ? 'No saved rituals yet'
                                        : 'No meditations found',
                                    style: TextStyle(
                                      color: AppTheme.getMutedColor(context),
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
        ),
        if (_isLoadingAd)
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
                      'Guided meditations for every moment',
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.getPrimary(context)
                      : AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.getPrimary(context)
                        : AppTheme.getBorderColor(context),
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? (AppTheme.isDark(context)
                              ? AppTheme.whiteText
                              : AppTheme.darkText)
                        : AppTheme.getMutedColor(context),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMeditationCard(
    Meditation meditation,
    bool isFavorite,
    bool isSaved,
    List<Meditation> playlist,
  ) {
    final isEvergreen = ContentAccessService.isEvergreen(meditation.id);
    final isSavedView = _selectedCategory == 'Saved';

    return FutureBuilder<AccessResult>(
      future: ContentAccessService.canAccess(
        sessionId: meditation.id,
        isPremiumContent: meditation.isPremium,
        isAdRequired: meditation.isAdRequired,
        isSubscriber: _isSubscriber,
      ),
      builder: (context, snapshot) {
        final accessResult = snapshot.data;
        final canAccess = accessResult?.canAccess ?? isEvergreen;
        final accessType =
            accessResult?.accessType ??
            (isEvergreen
                ? AccessType.evergreenFree
                : (meditation.isAdRequired
                      ? AccessType.adLocked
                      : AccessType.adLocked));

        final isLocked = !canAccess;

        return GestureDetector(
          onTap: () => _onMeditationTap(meditation, playlist),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.getCardColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.getBorderColor(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Cover/Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getCategoryColors(meditation.category),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: meditation.coverImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: meditation.coverImage,
                            fit: BoxFit.cover,
                            memCacheWidth: 150, // Optimize
                            fadeInDuration: Duration.zero,
                            placeholder: (context, url) =>
                                const SizedBox.shrink(),
                            errorWidget: (context, url, error) => Icon(
                              _getCategoryIcon(meditation.category),
                              color: Colors.white,
                              size: 24,
                            ),
                          )
                        : Icon(
                            _getCategoryIcon(meditation.category),
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Title & Duration
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meditation.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.getTextColor(context),
                              ),
                            ),
                          ),
                          // Access badge
                          _buildAccessBadge(
                            accessType,
                            accessResult?.remainingUnlockTime,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: AppTheme.getMutedColor(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${meditation.duration} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.getMutedColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Category Tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.getSageColor(
                                context,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              meditation.category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.getPrimary(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Action Button (Heart or Close)
                          if (isSavedView)
                            GestureDetector(
                              onTap: () {
                                final uid = AuthService().currentUserId;
                                if (uid != null) {
                                  FirestoreService().toggleListenLater(
                                    uid,
                                    meditation.id,
                                    false,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.red,
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () {
                                final uid = AuthService().currentUserId;
                                if (uid != null) {
                                  FirestoreService().toggleFavorite(
                                    uid,
                                    meditation.id,
                                    !isFavorite,
                                  );
                                }
                              },
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border_rounded,
                                size: 16, // Slightly larger for tap
                                color: isFavorite
                                    ? Colors.redAccent.withValues(alpha: 0.8)
                                    : AppTheme.getMutedColor(
                                        context,
                                      ).withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Lock or Play icon
                GestureDetector(
                  onTap: () {
                    final audioPlayer = context.read<AudioPlayerProvider>();
                    final isPlayingThis =
                        audioPlayer.isPlaying &&
                        audioPlayer.currentMeditation?.id == meditation.id;

                    if (isPlayingThis) {
                      audioPlayer.pause();
                    } else if (isLocked) {
                      // Delegate to main handler for paywall/ads
                      _onMeditationTap(meditation, playlist);
                    } else {
                      // Accessible - Play Inline
                      audioPlayer.play(meditation, playlist: playlist);
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isLocked
                          ? AppTheme.getMutedColor(
                              context,
                            ).withValues(alpha: 0.1)
                          : AppTheme.getSageColor(
                              context,
                            ).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Consumer<AudioPlayerProvider>(
                      builder: (context, audioPlayer, child) {
                        final isPlayingThis =
                            audioPlayer.isPlaying &&
                            audioPlayer.currentMeditation?.id == meditation.id;

                        return Icon(
                          isPlayingThis
                              ? Icons.pause
                              : (isLocked
                                    ? (accessType == AccessType.adLocked
                                          ? Icons.play_circle_outline
                                          : Icons.lock)
                                    : Icons.play_arrow),
                          color: isLocked
                              ? AppTheme.getMutedColor(context)
                              : AppTheme.getPrimary(context),
                          size: 20,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        final hours = remainingTime?.inHours ?? 0;
        final minutes = (remainingTime?.inMinutes ?? 0) % 60;
        text = '${hours}h ${minutes}m';
        bgColor = Colors.orange.withValues(alpha: 0.15);
        textColor = Colors.orange.shade700;
        icon = Icons.timer;
        break;
      case AccessType.adLocked:
        text = 'AD';
        bgColor = Colors.blue.withValues(alpha: 0.15);
        textColor = Colors.blue.shade700;
        icon = Icons.videocam;
        break;
      case AccessType.premiumLocked:
        text = 'PRO';
        bgColor = Colors.purple.withValues(alpha: 0.15);
        textColor = Colors.purple.shade700;
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
      case 'Anxiety':
        return [const Color(0xFF8DA399), const Color(0xFFB5C9BD)];
      case 'Stress':
        return [const Color(0xFFD4A373), const Color(0xFFE9C6A0)];
      case 'Morning':
        return [const Color(0xFFF2A65A), const Color(0xFFFFC78A)];
      case 'Evening':
        return [const Color(0xFF6B5B95), const Color(0xFF9789B3)];
      case 'Breathing':
        return [const Color(0xFF88B7B5), const Color(0xFFAAD0CE)];
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
      case 'Anxiety':
        return Icons.favorite;
      case 'Stress':
        return Icons.spa;
      case 'Morning':
        return Icons.wb_sunny;
      case 'Evening':
        return Icons.nights_stay;
      case 'Breathing':
        return Icons.air;
      default:
        return Icons.self_improvement;
    }
  }

  Widget _buildPaywallSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? AppTheme.backgroundDark
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.getBorderColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          // Premium Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.sageGreen, AppTheme.sageGreenDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.sageGreen.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Unlock Premium',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.getTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Get unlimited access to all meditations, exclusive content, and advanced features.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getMutedColor(context),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Features
          _buildFeatureRow(Icons.check_circle, 'All premium meditations'),
          _buildFeatureRow(Icons.check_circle, 'Offline downloads'),
          _buildFeatureRow(Icons.check_circle, 'Advanced statistics'),
          _buildFeatureRow(Icons.check_circle, 'Priority support'),

          const Spacer(),

          // CTA Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.sageGreen, AppTheme.sageGreenDark],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.sageGreen.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Start 7-Day Free Trial',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Then \$9.99/month • Cancel anytime',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.getMutedColor(context),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.getPrimary(context), size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
