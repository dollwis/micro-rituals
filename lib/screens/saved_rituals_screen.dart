import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/meditation.dart';
import '../models/firestore_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/offline_mode_service.dart';
import '../screens/audio_player_screen.dart';
import '../widgets/mini_audio_player.dart';

class SavedRitualsScreen extends StatelessWidget {
  const SavedRitualsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Library',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.getTextColor(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.getTextColor(context)),
      ),
      body: const SavedRitualsList(),
      bottomNavigationBar: const MiniAudioPlayer(),
    );
  }
}

class SavedRitualsList extends StatefulWidget {
  const SavedRitualsList({super.key});

  @override
  State<SavedRitualsList> createState() => _SavedRitualsListState();
}

class _SavedRitualsListState extends State<SavedRitualsList> {
  String _selectedFilter = 'Saved'; // 'Saved' or 'Downloads'
  final OfflineModeService _offlineService = OfflineModeService();

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUserId;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    final firestoreService = FirestoreService();

    return StreamBuilder<FirestoreUser?>(
      stream: firestoreService.streamUserStats(uid),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = userSnapshot.data!;
        final isPremium = user.isSubscriber;

        return Column(
          children: [
            // Filter Chips (Only if Premium)
            if (isPremium)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _buildFilterChip('Saved'),
                    const SizedBox(width: 12),
                    _buildFilterChip('Downloads'),
                  ],
                ),
              ),

            Expanded(
              child: _selectedFilter == 'Downloads'
                  ? _buildDownloadsList(firestoreService, user)
                  : _buildSavedList(firestoreService, user),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isSelected
                ? (AppTheme.isDark(context)
                      ? AppTheme.whiteText
                      : AppTheme.darkText)
                : AppTheme.getMutedColor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadsList(
    FirestoreService firestoreService,
    FirestoreUser user,
  ) {
    return FutureBuilder<List<String>>(
      future: _offlineService.getDownloadedIds(),
      builder: (context, idsSnapshot) {
        // While loading IDs, show nothing or spinner?
        if (!idsSnapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final downloadedIds = idsSnapshot.data!;

        if (downloadedIds.isEmpty) {
          return _buildEmptyState(
            context,
            Icons.download_done,
            'No downloaded rituals',
            'Download premium content to listen offline',
          );
        }

        return StreamBuilder<List<Meditation>>(
          stream: firestoreService.streamMeditations(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allMeditations = snapshot.data!;
            final downloadedRituals = allMeditations
                .where((m) => downloadedIds.contains(m.id))
                .toList();

            if (downloadedRituals.isEmpty) {
              return _buildEmptyState(
                context,
                Icons.download_done,
                'No downloaded rituals found',
                'Download premium content to listen offline',
              );
            }

            return ListView.builder(
              itemCount: downloadedRituals.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                return _buildRitualCard(
                  context,
                  downloadedRituals[index],
                  isDownloadView: true,
                  onRemove: () async {
                    await _offlineService.removeTrack(
                      downloadedRituals[index].id,
                    );
                    setState(() {}); // Refresh list
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSavedList(
    FirestoreService firestoreService,
    FirestoreUser user,
  ) {
    final savedIds = user.listenLaterIds;

    if (savedIds.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.watch_later_outlined,
        'Your collection is empty',
        'Swipe down on cards to listen later',
      );
    }

    return StreamBuilder<List<Meditation>>(
      stream: firestoreService.streamMeditations(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allMeditations = snapshot.data!;
        final savedRituals = allMeditations
            .where((m) => savedIds.contains(m.id))
            .toList();

        if (savedRituals.isEmpty) {
          return Center(
            child: Text(
              'No matches found',
              style: TextStyle(color: AppTheme.getMutedColor(context)),
            ),
          );
        }

        return ListView.builder(
          itemCount: savedRituals.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemBuilder: (context, index) {
            final ritual = savedRituals[index];
            return _buildRitualCard(
              context,
              ritual,
              isDownloadView: false,
              onRemove: () {
                firestoreService.toggleListenLater(user.uid, ritual.id, false);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppTheme.getMutedColor(context).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.getMutedColor(context),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.getMutedColor(context).withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRitualCard(
    BuildContext context,
    Meditation ritual, {
    required bool isDownloadView,
    required VoidCallback onRemove,
  }) {
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.getPrimary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              image: ritual.coverImage.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(ritual.coverImage),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: ritual.coverImage.isEmpty
                ? Icon(
                    Icons.self_improvement,
                    color: AppTheme.getPrimary(context),
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ritual.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.getTextColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.getSageColor(
                          context,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ritual.category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.getSageColor(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${ritual.duration} min',
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

          // Actions Row
          // Remove Button
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

          // Play Button
          GestureDetector(
            onTap: () {
              // Logic: Only remove from Saved list on play?
              // Existing logic: "Auto-remove when played" for Saved list toggled by user preference?
              // The user requirement didn't specify auto-remove, but the original code did:
              // "Auto-remove when played" -> firestoreService.toggleListenLater(uid, ritual.id, false);
              // I will KEEP that behavior for Saved list, but DIFFERENT for Downloads (don't delete on play).

              if (!isDownloadView) {
                onRemove();
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AudioPlayerScreen(meditation: ritual),
                ),
              );
            },
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
}
