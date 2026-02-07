import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';

class MigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update all meditations to extract duration from existing audio URLs
  Future<void> extractDurationsForAllMeditations() async {
    try {
      // Get all meditations
      final snapshot = await _firestore.collection('meditations').get();

      int updated = 0;
      int failed = 0;
      int skipped = 0;

      debugPrint(
        'Found ${snapshot.docs.length} documents. Starting migration...',
      );

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final audioUrl = data['audio_url'] as String?;

          if (audioUrl == null || audioUrl.isEmpty) {
            skipped++;
            continue;
          }

          // Check if duration already exists and is valid (not 0)
          if (data.containsKey('duration') &&
              data['duration'] != null &&
              data['duration'] > 0) {
            debugPrint(
              'Skipping ${doc.id} - already has duration: ${data['duration']}',
            );
            skipped++;
            continue;
          }

          debugPrint('Processing ${doc.id}...');

          // Extract duration
          final player = AudioPlayer();
          try {
            // Need to set the URL to get duration
            final durationObj = await player.setUrl(audioUrl);

            // If setUrl returns duration, use it, otherwise try getter
            final duration = durationObj ?? player.duration;

            if (duration != null) {
              final minutes = (duration.inSeconds / 60).ceil();

              await doc.reference.update({
                'duration': minutes,
                'duration_seconds': duration.inSeconds,
              });

              updated++;
              debugPrint('✅ Updated ${doc.id}: $minutes min');
            } else {
              debugPrint('⚠️ Could not determine duration for ${doc.id}');
              failed++;
            }
          } catch (audioError) {
            debugPrint('⚠️ Audio error for ${doc.id}: $audioError');
            failed++;
          } finally {
            await player.dispose();
          }
        } catch (e) {
          failed++;
          debugPrint('❌ Failed to update ${doc.id}: $e');
        }
      }

      debugPrint(
        'Migration complete: $updated updated, $skipped skipped, $failed failed',
      );
    } catch (e) {
      debugPrint('Migration error: $e');
      rethrow;
    }
  }
}
