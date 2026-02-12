import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/meditation.dart';
import '../providers/audio_player_provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/firestore_user.dart';
import '../widgets/download_icon.dart';

class AudioPlayerScreen extends StatefulWidget {
  final Meditation meditation;
  final List<Meditation>? playlist;

  const AudioPlayerScreen({super.key, required this.meditation, this.playlist});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    // Start playing automatically if it's a new track
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<AudioPlayerProvider>();
      if (player.currentMeditation?.id != widget.meditation.id) {
        player.play(widget.meditation, playlist: widget.playlist);
      }
    });

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    final Color primaryColor = AppTheme.getPrimary(context);
    final Color textColor = AppTheme.getTextColor(context);
    final Color mutedColor = AppTheme.getMutedColor(context);
    final bool isDark = AppTheme.isDark(context);

    // Dynamic background color based on theme
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Consumer<AudioPlayerProvider>(
        builder: (context, player, child) {
          final currentMeditation =
              player.currentMeditation ?? widget.meditation;
          final isPlaying = player.isPlaying;

          if (!isPlaying) {
            _rippleController.stop();
          } else if (!_rippleController.isAnimating) {
            _rippleController.repeat();
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                // Calculate artwork size
                double artworkSize = availableHeight * 0.35;
                if (artworkSize > 320) artworkSize = 320;
                if (artworkSize < 240) artworkSize = 240;

                return Column(
                  children: [
                    // Header Section
                    Padding(
                      padding: const EdgeInsets.only(top: 48, bottom: 24),
                      child: Column(
                        children: [
                          Text(
                            'NOW PLAYING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3.0,
                              color: mutedColor.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              currentMeditation.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.normal,
                                letterSpacing: -0.5,
                                color: textColor.withValues(alpha: 0.9),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentMeditation.category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 2.0,
                              color: textColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Artwork Section
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: artworkSize,
                          height: artworkSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Ripples (Subtle)
                              if (isPlaying) ...[
                                _buildRipple(1, primaryColor, artworkSize),
                                _buildRipple(2, primaryColor, artworkSize),
                                _buildRipple(3, primaryColor, artworkSize),
                              ],

                              // Main Image Container
                              Container(
                                width: artworkSize,
                                height: artworkSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.3 : 0.1,
                                      ),
                                      blurRadius: 60,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: currentMeditation.coverImage,
                                    fit: BoxFit.cover,
                                    memCacheWidth:
                                        600, // Optimization: limit memory usage
                                    memCacheHeight: 600,
                                    placeholder: (context, url) => Container(
                                      color: primaryColor.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: primaryColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          child: Icon(
                                            Icons.music_note,
                                            color: primaryColor,
                                            size: 48,
                                          ),
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Controls Section
                    Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: Column(
                        children: [
                          // Main Transport Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Previous
                              Semantics(
                                label: 'Previous track',
                                button: true,
                                enabled:
                                    player.hasPrevious ||
                                    player.position.inSeconds > 3,
                                hint:
                                    (player.hasPrevious ||
                                        player.position.inSeconds > 3)
                                    ? 'Double tap to skip to previous track'
                                    : 'Previous track not available',
                                child: _buildTransportButton(
                                  icon: Icons.skip_previous_rounded,
                                  size: 32,
                                  color: textColor.withValues(alpha: 0.3),
                                  onTap:
                                      (player.hasPrevious ||
                                          player.position.inSeconds > 3)
                                      ? player.skipPrevious
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 32),

                              // Play/Pause
                              Semantics(
                                label: isPlaying ? 'Pause' : 'Play',
                                button: true,
                                hint: isPlaying
                                    ? 'Double tap to pause'
                                    : 'Double tap to play',
                                child: GestureDetector(
                                  onTap: player.togglePlayPause,
                                  child: Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: textColor.withValues(alpha: 0.05),
                                      border: Border.all(
                                        color: textColor.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 44,
                                      color: textColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 32),

                              // Next
                              Semantics(
                                label: 'Next track',
                                button: true,
                                enabled: player.hasNext,
                                hint: player.hasNext
                                    ? 'Double tap to skip to next track'
                                    : 'Next track not available',
                                child: _buildTransportButton(
                                  icon: Icons.skip_next_rounded,
                                  size: 32,
                                  color: textColor.withValues(alpha: 0.3),
                                  onTap: player.hasNext
                                      ? player.skipNext
                                      : null,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 64),

                          // Secondary Actions ROW
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Shuffle Toggle
                              _buildSecondaryAction(
                                icon: Icons.shuffle_rounded,
                                isActive: player.isShuffleMode,
                                onTap: player.toggleShuffle,
                                color: textColor,
                              ),
                              const SizedBox(width: 48),

                              // Download (Placeholder/Wrapped)
                              _buildDownloadWrapper(
                                context,
                                currentMeditation,
                                textColor,
                              ),

                              const SizedBox(width: 48),

                              // Favorite
                              _buildFavoriteButton(
                                context,
                                activeColor: Colors.redAccent,
                                inactiveColor: textColor.withValues(alpha: 0.3),
                              ),

                              const SizedBox(width: 48),

                              // Close/Minimize
                              _buildSecondaryAction(
                                icon: Icons.keyboard_arrow_down_rounded,
                                isActive: false,
                                onTap: () => Navigator.pop(context),
                                color: textColor,
                              ),
                            ],
                          ),

                          // Decorative bottom bar
                          const SizedBox(height: 32),
                          Container(
                            width: 128,
                            height: 4,
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildRipple(int index, Color color, double size) {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        // final value = (_rippleController.value + (index * 0.33)) % 1.0;
        // Unused for now as ripples are disabled
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTransportButton({
    required IconData icon,
    required double size,
    required Color color,
    VoidCallback? onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      iconSize: size,
      color: onTap != null ? color.withOpacity(0.8) : color.withOpacity(0.1),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
    );
  }

  Widget _buildSecondaryAction({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
  }) {
    return IconButton(
      onPressed: onTap,
      iconSize: 20,
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(),
      icon: Icon(icon, color: isActive ? color : color.withValues(alpha: 0.3)),
      tooltip: '',
    );
  }

  Widget _buildDownloadWrapper(
    BuildContext context,
    Meditation meditation,
    Color color,
  ) {
    // DownloadIcon already handles auth and premium checks internally
    // No need for wrapper logic that blocks pointer events
    return DownloadIcon(
      meditation: meditation,
      activeColor: color,
      inactiveColor: color.withValues(alpha: 0.3),
      size: 20,
    );
  }

  Widget _buildFavoriteButton(
    BuildContext context, {
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final uid = authService.currentUserId;

    if (uid == null)
      return Semantics(
        label: 'Favorite',
        enabled: false,
        hint: 'Sign in to add favorites',
        child: Icon(
          Icons.favorite_outline_rounded,
          size: 20,
          color: inactiveColor,
        ),
      );

    return StreamBuilder<FirestoreUser?>(
      stream: firestoreService.streamUserStats(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isFavorite =
            user?.favoriteIds.contains(widget.meditation.id) ?? false;

        return IconButton(
          onPressed: () {
            firestoreService.toggleFavorite(
              uid,
              widget.meditation.id,
              !isFavorite,
            );
          },
          iconSize: 20,
          padding: const EdgeInsets.all(12), // Larger tap target
          constraints: const BoxConstraints(), // Remove default constraints
          icon: Icon(
            isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_outline_rounded,
            color: isFavorite ? activeColor : inactiveColor,
          ),
          tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
        );
      },
    );
  }
}
