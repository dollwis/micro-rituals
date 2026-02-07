import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

/// Service for uploading audio files and extracting metadata
class AudioUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload audio file and automatically extract duration
  /// Returns: Map with 'audioUrl' and 'duration' in minutes
  Future<Map<String, dynamic>> uploadAudioWithDuration({
    required PlatformFile audioFile,
    required String meditationId,
    Function(double)? onProgress,
  }) async {
    try {
      // Step 1: Extract duration BEFORE uploading
      final duration = await _extractAudioDuration(audioFile);

      debugPrint('Extracted audio duration: $duration minutes');

      // Step 2: Upload to Firebase Storage
      final audioUrl = await _uploadToStorage(
        audioFile,
        meditationId,
        onProgress: onProgress,
      );

      debugPrint('Uploaded to: $audioUrl');

      return {
        'audioUrl': audioUrl,
        'durationMinutes': duration,
        'durationSeconds': (duration * 60).round(),
      };
    } catch (e) {
      debugPrint('Error uploading audio: $e');
      rethrow;
    }
  }

  /// Extract audio duration from file
  Future<int> _extractAudioDuration(PlatformFile audioFile) async {
    final player = AudioPlayer();

    try {
      Duration? duration;

      if (kIsWeb) {
        // Web: Use bytes
        if (audioFile.bytes != null) {
          await player.setAudioSource(
            AudioSource.uri(
              Uri.dataFromBytes(audioFile.bytes!, mimeType: 'audio/mpeg'),
            ),
          );
          duration = player.duration;
        }
      } else {
        // Mobile/Desktop: Use file path
        if (audioFile.path != null) {
          await player.setFilePath(audioFile.path!);
          duration = player.duration;
        }
      }

      // Sometimes duration isn't available immediately, wait a bit
      if (duration == null) {
        // Try getting it again after a short delay or state change
        // For simplicity/safety, we might rely on the player having loaded the source.
        duration = await player.load();
      }

      await player.dispose();

      if (duration == null) {
        // Fallback or throw? Let's throw for now as this is the core feature
        throw Exception('Could not extract audio duration');
      }

      // Convert to minutes (rounded up)
      final minutes = (duration.inSeconds / 60).ceil();
      return minutes;
    } catch (e) {
      await player.dispose();
      debugPrint('Error extracting duration: $e');
      rethrow;
    }
  }

  /// Upload file to Firebase Storage
  Future<String> _uploadToStorage(
    PlatformFile audioFile,
    String meditationId, {
    Function(double)? onProgress,
  }) async {
    try {
      final fileName = audioFile.name;
      final ref = _storage.ref().child(
        'meditations/audio/$meditationId/$fileName',
      );

      UploadTask uploadTask;

      if (kIsWeb) {
        // Web upload
        if (audioFile.bytes == null) {
          throw Exception('No file data available for web upload');
        }
        uploadTask = ref.putData(
          audioFile.bytes!,
          SettableMetadata(contentType: 'audio/mpeg'),
        );
      } else {
        // Mobile/Desktop upload
        if (audioFile.path == null) {
          throw Exception('No file path available for upload');
        }
        uploadTask = ref.putFile(
          File(audioFile.path!),
          SettableMetadata(contentType: 'audio/mpeg'),
        );
      }

      // Track upload progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress);
          }
        });
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading to storage: $e');
      rethrow;
    }
  }

  /// Complete workflow: Pick file, upload, and save to Firestore
  Future<void> uploadNewMeditation({
    required String title,
    required String category,
    bool isPremium = false,
    String? coverImageUrl,
    Function(double)? onProgress,
  }) async {
    try {
      // Step 1: Pick audio file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        throw Exception(
          'No file selected',
        ); // Or just return silently? Throwing allows UI to know.
      }

      final audioFile = result.files.first;

      // Step 2: Create meditation document ID
      final docRef = _firestore.collection('meditations').doc();
      final meditationId = docRef.id;

      // Step 3: Upload audio and extract duration
      final uploadResult = await uploadAudioWithDuration(
        audioFile: audioFile,
        meditationId: meditationId,
        onProgress: onProgress,
      );

      // Step 4: Save to Firestore with auto-extracted duration
      await docRef.set({
        'id': meditationId, // Good practice to include ID
        'title': title,
        'category': category,
        'duration': uploadResult['durationMinutes'], // ✅ Auto-extracted!
        'duration_seconds': uploadResult['durationSeconds'],
        'audio_url': uploadResult['audioUrl'],
        'cover_image': coverImageUrl ?? '',
        'is_premium': isPremium,
        'is_ad_required': false, // Defaulting to false for now
        'created_at': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '✅ Meditation saved with auto-extracted duration: ${uploadResult['durationMinutes']} min',
      );
    } catch (e) {
      debugPrint('Error in complete upload workflow: $e');
      rethrow;
    }
  }
}
