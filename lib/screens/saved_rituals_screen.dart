import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/meditation.dart';
import '../models/firestore_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/offline_mode_service.dart';
import 'package:provider/provider.dart';
import '../providers/user_stats_provider.dart';
import '../screens/audio_player_screen.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/meditation_card.dart';

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
  final ValueNotifier<String> _selectedFilter = ValueNotifier(
    'Saved',
  ); // 'Saved' or 'Downloads'
  final OfflineModeService _offlineService = OfflineModeService();

  @override
  void dispose() {
    _selectedFilter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUserId;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    final firestoreService = FirestoreService();

    return Consumer<UserStatsProvider>(
      builder: (context, userStatsProvider, child) {
        final user = userStatsProvider.userStats;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

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
                child: ValueListenableBuilder<String>(
                  valueListenable: _selectedFilter,
                  builder: (context, selectedFilter, child) {
                    return CategoryFilterChips(
                      selectedCategory: selectedFilter,
                      categories: const ['Saved', 'Downloads'],
                      onCategorySelected: (filter) {
                        _selectedFilter.value = filter;
                      },
                    );
                  },
                ),
              ),

            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _selectedFilter,
                builder: (context, selectedFilter, child) {
                  return selectedFilter == 'Downloads'
                      ? _buildDownloadsList(firestoreService, user)
                      : _buildSavedList(firestoreService, user);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Removed _buildFilterChip - now using CategoryFilterChips widget

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
    return MeditationCard(
      meditation: ritual,
      variant: MeditationCardVariant.compact,
      isDownloadView: isDownloadView,
      onRemove: onRemove,
      onPlay: () {
        // Auto-remove from Saved list on play
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
    );
  }
}
