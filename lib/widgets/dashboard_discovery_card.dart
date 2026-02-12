import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/meditation.dart';
import '../widgets/ritual_cover_image.dart';

import '../providers/preview_audio_provider.dart';

/// Discovery card for meditation sessions with audio preview
class DashboardDiscoveryCard extends StatefulWidget {
  final Meditation meditation;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onTap;

  const DashboardDiscoveryCard({
    super.key,
    required this.meditation,
    required this.isSaved,
    required this.onSave,
    required this.onTap,
  });

  @override
  State<DashboardDiscoveryCard> createState() => _DashboardDiscoveryCardState();
}

class _DashboardDiscoveryCardState extends State<DashboardDiscoveryCard> {
  @override
  void dispose() {
    // Stop preview if still playing
    final previewProvider = Provider.of<PreviewAudioProvider>(
      context,
      listen: false,
    );
    if (previewProvider.isPreviewPlaying) {
      previewProvider.stopPreview();
    }
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'meditation':
        return Icons.self_improvement;
      case 'sleep':
        return Icons.nightlight_round;
      case 'focus':
        return Icons.center_focus_strong;
      case 'anxiety':
        return Icons.psychology;
      case 'stress':
        return Icons.spa;
      default:
        return Icons.self_improvement;
    }
  }

  List<Color> _getCategoryColors(String category) {
    switch (category.toLowerCase()) {
      case 'meditation':
        return [const Color(0xFF6B4CE6), const Color(0xFF9B7EF5)];
      case 'sleep':
        return [const Color(0xFF4A5FBD), const Color(0xFF6B7FD7)];
      case 'focus':
        return [const Color(0xFFE67E4C), const Color(0xFFF59B7E)];
      case 'anxiety':
        return [const Color(0xFF4CE6A9), const Color(0xFF7EF5C4)];
      case 'stress':
        return [const Color(0xFFBD4A85), const Color(0xFFD76BA0)];
      default:
        return [AppTheme.sageGreen, AppTheme.sageGreenDark];
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 160,
        height: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full Background Image
              widget.meditation.coverImage.isNotEmpty
                  ? RitualCoverImage(
                      imageUrl: widget.meditation.coverImage,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      fadeInDuration: Duration.zero,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getCategoryColors(
                              widget.meditation.category,
                            ),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getCategoryColors(
                              widget.meditation.category,
                            ),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _getCategoryIcon(widget.meditation.category),
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getCategoryColors(
                            widget.meditation.category,
                          ),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _getCategoryIcon(widget.meditation.category),
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),

              // Bottom Gradient Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),

              // Title and Category (overlaid at bottom)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.meditation.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.meditation.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Save Button (top-left) - wrapped to absorb taps
              Positioned(
                top: 8,
                left: 8,
                child: AbsorbPointer(
                  absorbing: false,
                  child: GestureDetector(
                    onTap: widget.onSave,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),

              // Play/Pause Button (top-right) - wrapped to absorb taps
              Positioned(
                top: 8,
                right: 8,
                child: AbsorbPointer(
                  absorbing: false,
                  child: Consumer<PreviewAudioProvider>(
                    builder: (context, previewProvider, child) {
                      final isThisPlaying = previewProvider.isPlayingUrl(
                        widget.meditation.audioUrl,
                      );
                      // Sync local state if needed, or just use this directly
                      // Logic: If this specific URL is playing in provider, show pause.

                      return GestureDetector(
                        onTap: () {
                          if (isThisPlaying) {
                            previewProvider.stopPreview();
                          } else {
                            if (widget.meditation.audioUrl.isNotEmpty) {
                              previewProvider.playPreview(
                                widget.meditation.audioUrl,
                              );
                            }
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isThisPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
