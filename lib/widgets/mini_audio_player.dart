import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_player_provider.dart';
import '../models/meditation.dart';
import '../theme/app_theme.dart';
import '../screens/audio_player_screen.dart';

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Selector only rebuilds when the current meditation changes (null <-> not null, or different track)
    return Selector<AudioPlayerProvider, Meditation?>(
      selector: (_, player) => player.currentMeditation,
      builder: (context, currentMeditation, child) {
        if (currentMeditation == null) {
          return const SizedBox.shrink();
        }

        // 2. Delegate to a static widget that manages its own fine-grained updates
        //    This prevents the entire MiniAudioPlayer structure from rebuilding on every provider change.
        return _MiniPlayerContent(meditation: currentMeditation);
      },
    );
  }
}

class _MiniPlayerContent extends StatelessWidget {
  final Meditation meditation;

  const _MiniPlayerContent({required this.meditation});

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<AudioPlayerProvider>(context, listen: false);
    final isDark = AppTheme.isDark(context);
    final textColor = AppTheme.getTextColor(context);
    final primaryColor = AppTheme.getPrimary(context);

    // We only access simple values that don't change often here.
    // Dynamic values (position, playing state) are handled by ValueListenableBuilders below.

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioPlayerScreen(meditation: meditation),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.getBackground(context).withValues(alpha: 0.9)
                      : AppTheme.getCardColor(context).withValues(alpha: 0.95),
                  border: Border(
                    top: BorderSide(color: AppTheme.getBorderColor(context)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Cover Image
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: meditation.coverImage.isNotEmpty
                                  ? DecorationImage(
                                      image: ResizeImage(
                                        kIsWeb
                                            ? NetworkImage(
                                                meditation.coverImage,
                                              )
                                            : CachedNetworkImageProvider(
                                                    meditation.coverImage,
                                                  )
                                                  as ImageProvider,
                                        width: 120, // Optimization
                                        height: 120,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: primaryColor.withValues(alpha: 0.1),
                            ),
                            child: meditation.coverImage.isEmpty
                                ? Icon(Icons.music_note, color: primaryColor)
                                : null,
                          ),
                          const SizedBox(width: 12),

                          // Title
                          Expanded(
                            child: Text(
                              meditation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),

                          // Controls
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Rewind 10s
                              IconButton(
                                icon: const Icon(Icons.replay_10),
                                onPressed: player.rewind10,
                                color: primaryColor,
                                iconSize: 24,
                              ),
                              // Play/Pause - Uses ValueListenableBuilder
                              ValueListenableBuilder<bool>(
                                valueListenable: player.isPlayingNotifier,
                                builder: (context, isPlaying, child) {
                                  return IconButton(
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                    ),
                                    onPressed: player.togglePlayPause,
                                    color: primaryColor,
                                    iconSize: 40,
                                  );
                                },
                              ),
                              // Forward 10s
                              IconButton(
                                icon: const Icon(Icons.forward_10),
                                onPressed: player.forward10,
                                color: primaryColor,
                                iconSize: 24,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Progress Bar - Uses ValueListenableBuilder
                    ValueListenableBuilder<Duration>(
                      valueListenable: player.positionNotifier,
                      builder: (context, position, child) {
                        double progress = 0.0;
                        if (player.duration.inMilliseconds > 0) {
                          progress =
                              position.inMilliseconds /
                              player.duration.inMilliseconds;
                          progress = progress.clamp(0.0, 1.0);
                        }
                        return LinearProgressIndicator(
                          value: progress,
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor,
                          ),
                          minHeight: 2,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
