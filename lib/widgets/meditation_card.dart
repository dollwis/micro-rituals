import 'package:flutter/material.dart';
import '../models/meditation.dart';
import '../theme/app_theme.dart';
import '../widgets/ritual_cover_image.dart';

/// Card variant for different use cases
enum MeditationCardVariant {
  /// Full featured card with all options (ZenVault style)
  full,

  /// Compact card for lists (SavedRituals style)
  compact,
}

/// Reusable meditation card widget that displays meditation information
/// with various interactive elements based on variant.
///
/// This widget consolidates duplicate card implementations across
/// zen_vault_screen.dart and saved_rituals_screen.dart.
class MeditationCard extends StatelessWidget {
  /// The meditation to display
  final Meditation meditation;

  /// Card variant - determines layout and features
  final MeditationCardVariant variant;

  /// Whether this meditation is favorited
  final bool isFavorite;

  /// Whether this meditation is saved for later
  final bool isSaved;

  /// Whether to show access badge (locked/premium/ad)
  final bool showAccessBadge;

  /// Access badge widget to show (if showAccessBadge is true)
  final Widget? accessBadge;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  /// Callback when favorite button is tapped (full variant only)
  final VoidCallback? onFavoriteToggle;

  /// Callback when save button is tapped (full variant only)
  final VoidCallback? onSaveToggle;

  /// Callback when remove button is tapped (compact variant only)
  final VoidCallback? onRemove;

  /// Callback when play button is tapped (compact variant only)
  final VoidCallback? onPlay;

  /// Whether this is a download view (affects remove icon)
  final bool isDownloadView;

  /// Category icon getter function
  final IconData Function(String category)? getCategoryIcon;

  /// Category colors getter function
  final List<Color> Function(String category)? getCategoryColors;

  /// Whether content should appear locked (darkened)
  final bool isLocked;

  const MeditationCard({
    super.key,
    required this.meditation,
    this.variant = MeditationCardVariant.full,
    this.isFavorite = false,
    this.isSaved = false,
    this.showAccessBadge = false,
    this.accessBadge,
    this.onTap,
    this.onFavoriteToggle,
    this.onSaveToggle,
    this.onRemove,
    this.onPlay,
    this.isDownloadView = false,
    this.getCategoryIcon,
    this.getCategoryColors,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case MeditationCardVariant.full:
        return _buildFullCard(context);
      case MeditationCardVariant.compact:
        return _buildCompactCard(context);
    }
  }

  /// Full variant card (ZenVault style)
  Widget _buildFullCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLocked
              ? Color.alphaBlend(
                  Colors.black.withValues(alpha: 0.1),
                  AppTheme.getCardColor(context),
                )
              : AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: isLocked
              ? null
              : Border.all(color: AppTheme.getBorderColor(context)),
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
            Stack(
              children: [
                _buildCoverImage(context, size: 56),
                if (isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
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
                        child: Opacity(
                          opacity: isLocked ? 0.5 : 1.0,
                          child: Text(
                            meditation.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextColor(context),
                            ),
                          ),
                        ),
                      ),
                      // Access badge
                      if (showAccessBadge && accessBadge != null) accessBadge!,
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Category Tag only (duration removed)
                  Opacity(
                    opacity: isLocked ? 0.5 : 1.0,
                    child: _buildCategoryTag(context),
                  ),
                ],
              ),
            ),

            // Action Buttons (Favorite & Save)
            if (onFavoriteToggle != null || onSaveToggle != null) ...[
              const SizedBox(width: 8),
              _buildActionButtons(context),
            ],
          ],
        ),
      ),
    );
  }

  /// Compact variant card (SavedRituals style)
  Widget _buildCompactCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.getBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cover Image
          _buildCoverImage(context, size: 48),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meditation.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildCategoryTag(context, uppercase: true, compact: true),
                    const SizedBox(width: 8),
                    Text(
                      meditation.formattedDuration,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getMutedColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions Row (Remove + Play)
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  isDownloadView ? Icons.delete_outline : Icons.close,
                  color: isDownloadView
                      ? Colors.red.withValues(alpha: 0.7)
                      : AppTheme.getMutedColor(context),
                  size: 20,
                ),
              ),
            ),

          if (onPlay != null)
            GestureDetector(
              onTap: onPlay,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.getPrimary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: AppTheme.getPrimary(context),
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build cover image with fallback icon
  Widget _buildCoverImage(BuildContext context, {required double size}) {
    final categoryColors =
        getCategoryColors?.call(meditation.category) ??
        [AppTheme.getPrimary(context), AppTheme.getPrimary(context)];

    final categoryIcon =
        getCategoryIcon?.call(meditation.category) ?? Icons.self_improvement;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: categoryColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: meditation.coverImage.isNotEmpty
            ? RitualCoverImage(
                imageUrl: meditation.coverImage,
                fit: BoxFit.cover,
                memCacheWidth: 150,
                fadeInDuration: Duration.zero,
                placeholder: (context, url) => const SizedBox.shrink(),
                errorWidget: (context, url, error) =>
                    Icon(categoryIcon, color: Colors.white, size: size * 0.4),
              )
            : Icon(categoryIcon, color: Colors.white, size: size * 0.4),
      ),
    );
  }

  /// Build category tag pill
  Widget _buildCategoryTag(
    BuildContext context, {
    bool uppercase = false,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.getSageColor(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(compact ? 4 : 8),
      ),
      child: Text(
        uppercase ? meditation.category.toUpperCase() : meditation.category,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.getSageColor(context),
        ),
      ),
    );
  }

  /// Build action buttons for full variant
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Favorite button
        if (onFavoriteToggle != null)
          GestureDetector(
            onTap: onFavoriteToggle,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: isFavorite
                    ? Colors.redAccent
                    : AppTheme.getMutedColor(context),
              ),
            ),
          ),
      ],
    );
  }
}
