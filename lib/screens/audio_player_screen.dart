import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/meditation.dart';
import '../providers/audio_player_provider.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/firestore_user.dart';
import '../widgets/breathing_cover_image.dart';
import '../widgets/download_icon.dart';

class AudioPlayerScreen extends StatefulWidget {
  final Meditation meditation;
  final List<Meditation>? playlist;

  const AudioPlayerScreen({super.key, required this.meditation, this.playlist});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  @override
  void initState() {
    super.initState();
    // Start playing automatically if it's a new track
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final player = context.read<AudioPlayerProvider>();
      // Only play if it's a different track or not playing
      if (player.currentMeditation?.id != widget.meditation.id) {
        player.play(widget.meditation, playlist: widget.playlist);
      }
    });
  }

  String _formatTime(Duration duration) {
    // ... existing formatTime code ...
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Theme Colors
    final Color primaryColor = AppTheme.getPrimary(context);
    final Color secondaryColor = AppTheme.getLavenderColor(context);
    final Color textColor = AppTheme.getTextColor(context);
    final Color mutedColor = AppTheme.getMutedColor(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<AudioPlayerProvider>(
        builder: (context, player, child) {
          final currentMeditation =
              player.currentMeditation ?? widget.meditation;

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                // Dynamically size the artwork based on available screen height
                // Default was 220, let's make it proportional but capped
                double artworkdSize = availableHeight * 0.25;
                if (artworkdSize > 220) artworkdSize = 220;
                if (artworkdSize < 120) artworkdSize = 120;

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16, // Reduced vertical padding
                          ),
                          child: Column(
                            children: [
                              Text(
                                'NOW PLAYING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  color: mutedColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentMeditation.title,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentMeditation.category,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Aroma/Breathing Ring Artwork
                        Center(
                          child: BreathingCoverImage(
                            imageUrl: currentMeditation.coverImage,
                            size: artworkdSize,
                            isPlaying: player.isPlaying,
                          ),
                        ),

                        // Controls Section
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16, // Reduced vertical padding
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Column(
                                  children: [
                                    // Progress Bar
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: primaryColor,
                                        inactiveTrackColor: secondaryColor,
                                        thumbColor: primaryColor,
                                        trackHeight: 6,
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 0,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                              overlayRadius: 0,
                                            ),
                                      ),
                                      child: Slider(
                                        value: player.position.inSeconds
                                            .toDouble()
                                            .clamp(
                                              0.0,
                                              player.duration.inSeconds
                                                          .toDouble() >
                                                      0
                                                  ? player.duration.inSeconds
                                                        .toDouble()
                                                  : 100.0,
                                            ),
                                        max:
                                            player.duration.inSeconds
                                                    .toDouble() >
                                                0
                                            ? player.duration.inSeconds
                                                  .toDouble()
                                            : 100,
                                        onChanged: (value) async {
                                          final position = Duration(
                                            seconds: value.toInt(),
                                          );
                                          await player.seek(position);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatTime(player.position),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: mutedColor,
                                          ),
                                        ),
                                        Text(
                                          _formatTime(player.duration),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: mutedColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: availableHeight > 600 ? 32 : 16),

                              // Main Controls
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Previous 10s
                                  IconButton(
                                    onPressed: player.rewind10,
                                    icon: const Icon(Icons.replay_10),
                                    iconSize: 24,
                                    color: primaryColor.withValues(alpha: 0.6),
                                  ),

                                  // Previous Track
                                  IconButton(
                                    onPressed:
                                        (player.hasPrevious ||
                                            player.position.inSeconds > 3)
                                        ? player.skipPrevious
                                        : null,
                                    icon: const Icon(
                                      Icons.skip_previous_rounded,
                                    ),
                                    iconSize: 42, // Reduced slightly
                                    color:
                                        (player.hasPrevious ||
                                            player.position.inSeconds > 3)
                                        ? primaryColor
                                        : mutedColor.withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(width: 8),

                                  // Play/Pause
                                  GestureDetector(
                                    onTap: player.togglePlayPause,
                                    child: Container(
                                      width: 64, // Reduced size
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        player.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Next Track
                                  IconButton(
                                    onPressed: player.hasNext
                                        ? player.skipNext
                                        : null,
                                    icon: const Icon(Icons.skip_next_rounded),
                                    iconSize: 42,
                                    color: player.hasNext
                                        ? primaryColor
                                        : mutedColor.withValues(alpha: 0.2),
                                  ),

                                  // Forward 10s
                                  IconButton(
                                    onPressed: player.forward10,
                                    icon: const Icon(Icons.forward_10),
                                    iconSize: 24,
                                    color: primaryColor.withValues(alpha: 0.6),
                                  ),
                                ],
                              ),

                              SizedBox(height: availableHeight > 600 ? 48 : 24),

                              // Bottom Actions (Use Wrap or Row with constraints)
                              Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .spaceEvenly, // improved spacing
                                children: [
                                  // Loop Toggle
                                  IconButton(
                                    onPressed: player.toggleLoop,
                                    icon: Icon(
                                      Icons.loop,
                                      color: player.isLooping
                                          ? primaryColor
                                          : mutedColor,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: player.isLooping
                                          ? primaryColor.withValues(alpha: 0.15)
                                          : null,
                                    ),
                                  ),

                                  // Download Button (Premium Only)
                                  _buildDownloadButton(
                                    context,
                                    currentMeditation,
                                    primaryColor,
                                    mutedColor,
                                  ),

                                  // Favorite Toggle
                                  _buildFavoriteButton(
                                    context,
                                    primaryColor,
                                    mutedColor,
                                  ),

                                  // Close / Minimize
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),

                              // Volume Slider (Separate Row for space)
                              if (availableHeight > 650) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: 200,
                                  decoration: BoxDecoration(
                                    color: secondaryColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        player.volume == 0
                                            ? Icons.volume_off
                                            : Icons.volume_up_rounded,
                                        size: 16,
                                        color: primaryColor,
                                      ),
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            activeTrackColor: primaryColor,
                                            inactiveTrackColor: primaryColor
                                                .withValues(alpha: 0.2),
                                            thumbColor: primaryColor,
                                            trackHeight: 3,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6,
                                                ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                  overlayRadius: 12,
                                                ),
                                          ),
                                          child: Slider(
                                            value: player.volume,
                                            onChanged: (value) =>
                                                player.setVolume(value),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    Meditation meditation,
    Color activeColor,
    Color inactiveColor,
  ) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final uid = authService.currentUserId;

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<FirestoreUser?>(
      stream: firestoreService.streamUserStats(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isSubscriber = user?.isSubscriber ?? false;

        if (!isSubscriber) return const SizedBox.shrink();

        // Check download status using a separate FutureBuilder or Stream
        // For simplicity and performance, we'll use a StatefulWidget wrapper
        // but here inline we can use a FutureBuilder that refreshes on tap
        return DownloadIcon(
          meditation: meditation,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
        );
      },
    );
  }

  Widget _buildFavoriteButton(
    BuildContext context,
    Color activeColor,
    Color inactiveColor,
  ) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final uid = authService.currentUserId;

    if (uid == null) return const SizedBox(width: 40); // Placeholder

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
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.redAccent : inactiveColor,
          ),
        );
      },
    );
  }
}
