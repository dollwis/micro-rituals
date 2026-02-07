import 'package:flutter/material.dart';
import 'ritual_cover_image.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../screens/audio_player_screen.dart';

class RitualHistoryList extends StatelessWidget {
  final int limit;

  const RitualHistoryList({super.key, this.limit = 10});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUserId;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    final firestoreService = FirestoreService();
    // Sage green accent color from StatsScreen
    const Color mutedTeal = Color(0xFF7DA8A5);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: firestoreService.streamCompletionHistory(uid, limit: limit),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'No rituals completed yet',
                style: TextStyle(color: AppTheme.getMutedColor(context)),
              ),
            ),
          );
        }

        final completions = snapshot.data!;

        // Aggregate consecutive duplicates and sum their minutes
        final aggregatedCompletions = <Map<String, dynamic>>[];

        for (final completion in completions) {
          if (aggregatedCompletions.isNotEmpty &&
              aggregatedCompletions.last['ritual_name'] ==
                  completion['ritual_name']) {
            // Same ritual as previous - aggregate
            final prev = aggregatedCompletions.last;
            final prevDuration = prev['duration_minutes'] as int? ?? 0;
            final currDuration = completion['duration_minutes'] as int? ?? 0;

            final prevSeconds =
                prev['duration_seconds'] as int? ?? (prevDuration * 60);
            final currSeconds =
                completion['duration_seconds'] as int? ?? (currDuration * 60);

            // Update the previous entry with new total
            prev['duration_minutes'] = prevDuration + currDuration;
            prev['duration_seconds'] = prevSeconds + currSeconds;

            // Add ID to list
            List<String> ids = prev['ids'] as List<String>;
            if (completion['id'] != null) {
              ids.add(completion['id']);
            }
          } else {
            // New or different ritual - add deep copy
            final newEntry = Map<String, dynamic>.from(completion);
            // Initialize IDs list with current ID
            newEntry['ids'] = completion['id'] != null
                ? <String>[completion['id']]
                : <String>[];
            aggregatedCompletions.add(newEntry);
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: aggregatedCompletions.take(limit).map((completion) {
              final completedAt = (completion['completed_at'] as dynamic)
                  .toDate();
              final dayName = _getDayName(completedAt.weekday);
              final timeStr = _formatTime(completedAt);
              final completionSeconds = completion['duration_seconds'] as int?;
              final completionMinutes =
                  completion['duration_minutes'] as int? ?? 0;
              final String duration;
              if (completionSeconds != null && completionSeconds > 0) {
                final m = completionSeconds ~/ 60;
                final s = completionSeconds % 60;
                duration = '${m}:${s.toString().padLeft(2, '0')}';
              } else {
                duration = '${completionMinutes}m';
              }
              final coverImageUrl = completion['cover_image_url'] as String?;

              return GestureDetector(
                onTap: () async {
                  final ritualName = completion['ritual_name'] as String?;
                  if (ritualName == null) return;

                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(
                      child: CircularProgressIndicator(color: mutedTeal),
                    ),
                  );

                  try {
                    final meditation = await firestoreService
                        .getMeditationByTitle(ritualName);

                    // Hide loading indicator
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }

                    if (meditation != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AudioPlayerScreen(meditation: meditation),
                        ),
                      );
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Audio for "$ritualName" not found'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    // Hide loading indicator on error
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error loading audio: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.getBorderColor(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.getPrimary(
                            context,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              coverImageUrl != null && coverImageUrl.isNotEmpty
                              ? RitualCoverImage(
                                  imageUrl: coverImageUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth:
                                      120, // Optimization: Decode smaller
                                  fadeInDuration:
                                      Duration.zero, // Instant if cached
                                  placeholder: (context, url) => Center(
                                    child: Icon(
                                      Icons.self_improvement,
                                      color: AppTheme.getPrimary(
                                        context,
                                      ).withValues(alpha: 0.5),
                                      size: 20,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Center(
                                    child: Icon(
                                      Icons.error_outline,
                                      color: Colors.red.withValues(alpha: 0.5),
                                      size: 20,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    Icons.self_improvement,
                                    color: AppTheme.getPrimary(context),
                                    size: 20,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              completion['ritual_name'] ?? 'Ritual',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.getTextColor(context),
                              ),
                            ),
                            Text(
                              '$dayName • $timeStr',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.getMutedColor(
                                  context,
                                ).withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        duration,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: mutedTeal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Play Button
                      Icon(
                        Icons.play_circle_outline,
                        color: AppTheme.getPrimary(context),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      // Delete Button
                      GestureDetector(
                        onTap: () async {
                          final ids = completion['ids'] as List;
                          if (ids.isEmpty) return;

                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: AppTheme.getCardColor(context),
                              title: Text(
                                'Remove from history?',
                                style: TextStyle(
                                  color: AppTheme.getTextColor(context),
                                ),
                              ),
                              content: Text(
                                'This will remove this session from your history.',
                                style: TextStyle(
                                  color: AppTheme.getMutedColor(context),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Remove',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            for (final id in ids) {
                              await firestoreService.deleteCompletion(uid, id);
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}
