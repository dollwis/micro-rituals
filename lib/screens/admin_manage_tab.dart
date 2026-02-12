import 'package:flutter/material.dart';
import '../models/meditation.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_ritual_dialog.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart'; // Import just_audio

class AdminManageTab extends StatefulWidget {
  const AdminManageTab({super.key});

  @override
  State<AdminManageTab> createState() => _AdminManageTabState();
}

class _AdminManageTabState extends State<AdminManageTab> {
  final _firestoreService = FirestoreService();
  bool _isSyncing = false;
  final Set<String> _selectedIds = {};

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text(
          'Delete $count Rituals?',
          style: TextStyle(color: AppTheme.getTextColor(context)),
        ),
        content: Text(
          'Are you sure you want to delete these $count items? This cannot be undone.',
          style: TextStyle(
            color: AppTheme.getTextColor(context).withValues(alpha: 0.8),
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
      setState(() => _isSyncing = true); // Reuse syncing spinner for deletion
      try {
        // Create a copy of ids to iterate safely
        final idsToDelete = List<String>.from(_selectedIds);

        // Delete each
        for (final id in idsToDelete) {
          await _firestoreService.deleteMeditation(id);
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Deleted $count rituals')));
          setState(() {
            _selectedIds.clear();
            _isSyncing = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSyncing = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting items: $e')));
        }
      }
    }
  }

  Future<void> _syncDurations() async {
    setState(() => _isSyncing = true);
    final scaffold = ScaffoldMessenger.of(context);

    try {
      final rituals = await _firestoreService.getAllMeditations();
      int updatedCount = 0;

      final player = AudioPlayer();

      for (final ritual in rituals) {
        if (ritual.durationSeconds == null || ritual.durationSeconds == 0) {
          try {
            if (ritual.audioUrl.isNotEmpty) {
              final duration = await player.setUrl(ritual.audioUrl);
              if (duration != null) {
                final seconds = duration.inSeconds;
                final minutes = (seconds / 60).round();

                final updatedRitual = ritual.copyWith(
                  durationSeconds: seconds,
                  duration: minutes > 0 ? minutes : 1,
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
            color: AppTheme.getTextColor(context).withValues(alpha: 0.8),
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
      floatingActionButton: _isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: _isSyncing ? null : _deleteSelected,
              backgroundColor: Colors.red,
              label: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Delete (${_selectedIds.length})',
                      style: const TextStyle(color: Colors.white),
                    ),
              icon: _isSyncing
                  ? null
                  : const Icon(Icons.delete, color: Colors.white),
            )
          : FloatingActionButton.extended(
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
              icon: _isSyncing
                  ? null
                  : const Icon(Icons.sync, color: Colors.white),
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

          return WillPopScope(
            onWillPop: () async {
              if (_isSelectionMode) {
                setState(() => _selectedIds.clear());
                return false;
              }
              return true;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: rituals.length,
              itemBuilder: (context, index) {
                final ritual = rituals[index];
                final isSelected = _selectedIds.contains(ritual.id);

                return GestureDetector(
                  onLongPress: () {
                    // Enter selection mode if not already, and select item
                    if (!_isSelectionMode) {
                      HapticFeedback.mediumImpact();
                    }
                    _toggleSelection(ritual.id);
                  },
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(ritual.id);
                    } else {
                      // Original behavior or no-op since it's admin manage
                      // Maybe verify edit? No, edit is a button.
                      // Let's just allow tapping to trigger edit?
                      // Old behavior didn't have tile tap.
                      // Let's leave it as no-op or optional edit.
                      // But effectively we want selection toggle only in mode.
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.getPrimary(context).withValues(alpha: 0.1)
                          : AppTheme.getCardColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.getPrimary(context)
                            : AppTheme.getBorderColor(context),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: _isSelectionMode
                          ? Transform.scale(
                              scale: 1.2,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (val) => _toggleSelection(ritual.id),
                                activeColor: AppTheme.getPrimary(context),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            )
                          : Container(
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
                      trailing: _isSelectionMode
                          ? null // Hide individual actions in selection mode
                          : Row(
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
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
