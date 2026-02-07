import 'package:flutter/material.dart';
import '../models/meditation.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_ritual_dialog.dart';
import 'package:just_audio/just_audio.dart'; // Import just_audio

class AdminManageTab extends StatefulWidget {
  const AdminManageTab({super.key});

  @override
  State<AdminManageTab> createState() => _AdminManageTabState();
}

class _AdminManageTabState extends State<AdminManageTab> {
  final _firestoreService = FirestoreService();
  bool _isSyncing = false;

  Future<void> _syncDurations() async {
    setState(() => _isSyncing = true);
    final scaffold = ScaffoldMessenger.of(context);

    try {
      final rituals = await _firestoreService.getAllMeditations();
      int updatedCount = 0;

      final player = AudioPlayer();

      for (final ritual in rituals) {
        // Check if durationSeconds is missing or likely defaulted (e.g. exactly minutes * 60)
        // Actually, let's just update any that don't have durationSeconds explicitly set to non-zero
        // OR if you want to force update all, remove the check.
        // For now, let's update if durationSeconds is null or 0.
        if (ritual.durationSeconds == null || ritual.durationSeconds == 0) {
          try {
            if (ritual.audioUrl.isNotEmpty) {
              final duration = await player.setUrl(ritual.audioUrl);
              if (duration != null) {
                final seconds = duration.inSeconds;
                final minutes = (seconds / 60).round();

                final updatedRitual = ritual.copyWith(
                  durationSeconds: seconds,
                  duration: minutes > 0
                      ? minutes
                      : 1, // Update minutes too if needed
                );

                await _firestoreService.updateMeditation(updatedRitual);
                updatedCount++;
              }
            }
          } catch (e) {
            debugPrint('Error syncing ${ritual.title}: $e');
          }
        }
      }

      player.dispose();

      if (mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Sync complete. Updated $updatedCount rituals.'),
            backgroundColor: AppTheme.sageGreenDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _editRitual(Meditation ritual) async {
    final updatedRitual = await showDialog<Meditation>(
      context: context,
      builder: (_) => EditRitualDialog(ritual: ritual),
    );

    if (updatedRitual != null) {
      await _firestoreService.updateMeditation(updatedRitual);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ritual updated successfully')),
        );
      }
    }
  }

  void _deleteRitual(Meditation ritual) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text(
          'Delete Ritual?',
          style: TextStyle(color: AppTheme.getTextColor(context)),
        ),
        content: Text(
          'Are you sure you want to delete "${ritual.title}"? This cannot be undone.',
          style: TextStyle(
            color: AppTheme.getTextColor(context).withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getMutedColor(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestoreService.deleteMeditation(ritual.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ritual deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSyncing ? null : _syncDurations,
        backgroundColor: AppTheme.getPrimary(context),
        label: _isSyncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Sync Durations',
                style: TextStyle(color: Colors.white),
              ),
        icon: _isSyncing ? null : const Icon(Icons.sync, color: Colors.white),
      ),
      body: StreamBuilder<List<Meditation>>(
        stream: _firestoreService.streamMeditations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rituals = snapshot.data!;

          if (rituals.isEmpty) {
            return Center(
              child: Text(
                'No rituals found.',
                style: TextStyle(color: AppTheme.getMutedColor(context)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: rituals.length,
            itemBuilder: (context, index) {
              final ritual = rituals[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.getBorderColor(context)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: ritual.coverImage.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(ritual.coverImage),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: AppTheme.getBackground(context),
                    ),
                    child: ritual.coverImage.isEmpty
                        ? Icon(
                            Icons.music_note,
                            color: AppTheme.getMutedColor(context),
                          )
                        : null,
                  ),
                  title: Text(
                    ritual.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextColor(context),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ritual.category} • ${ritual.formattedDuration}',
                        style: TextStyle(
                          color: AppTheme.getMutedColor(context),
                        ),
                      ),
                      if (ritual.isPremium)
                        Text(
                          'Premium',
                          style: TextStyle(
                            color: AppTheme.getPrimary(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (ritual.isAdRequired)
                        const Text(
                          'Ad Required',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        color: AppTheme.getPrimary(context),
                        onPressed: () => _editRitual(ritual),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red.withOpacity(0.7),
                        onPressed: () => _deleteRitual(ritual),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
