import 'package:flutter/material.dart';
import '../models/meditation.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_ritual_dialog.dart';

class AdminManageTab extends StatefulWidget {
  const AdminManageTab({super.key});

  @override
  State<AdminManageTab> createState() => _AdminManageTabState();
}

class _AdminManageTabState extends State<AdminManageTab> {
  final _firestoreService = FirestoreService();

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
    return StreamBuilder<List<Meditation>>(
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
                      '${ritual.category} • ${ritual.duration} min',
                      style: TextStyle(color: AppTheme.getMutedColor(context)),
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
    );
  }
}
