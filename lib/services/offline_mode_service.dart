import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/meditation.dart';
import './firestore_service.dart';

class OfflineModeService {
  final Dio _dio = Dio();
  static const String _downloadedIdsKey = 'downloaded_meditation_ids';

  // Singleton pattern
  static final OfflineModeService _instance = OfflineModeService._internal();
  factory OfflineModeService() => _instance;
  OfflineModeService._internal();

  /// Get the local directory for storing audio files
  /// On web, this is not used (files are streamed, not stored)
  Future<String> _getDownloadDirectory() async {
    if (kIsWeb) {
      // Web doesn't support local file storage
      return 'web_cache';
    }
    final directory = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${directory.path}/offline_audio');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  /// Get the local file path for a meditation ID
  Future<String> getLocalFilePath(String meditationId) async {
    final dir = await _getDownloadDirectory();
    // Assuming mp3 or similar. We will just use the ID as filename.
    // Ideally we should know the extension, but typically we can serve it to AudioPlayer
    // as a file and it figures it out or we append .mp3 if needed.
    // Let's safe-bet and append .mp3 if the URL had it, but for simplicity:
    return '$dir/$meditationId.mp3';
  }

  /// Check if user can download (premium verification)
  Future<bool> canDownload(String userId) async {
    try {
      final user = await FirestoreService().getUserStats(userId);
      return user?.hasActiveSubscription ?? false;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  /// Check if a track is downloaded (and file exists)
  Future<bool> isTrackDownloaded(String meditationId) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedIds = prefs.getStringList(_downloadedIdsKey) ?? [];

    if (!downloadedIds.contains(meditationId)) return false;

    // On web, we just check if it's in the list
    if (kIsWeb) return true;

    // On mobile, also verify file exists
    final path = await getLocalFilePath(meditationId);
    return File(path).exists();
  }

  /// Download a track (with premium verification)
  Future<void> downloadTrack(
    Meditation meditation,
    String userId, {
    Function(double)? onProgress,
  }) async {
    // Verify premium status
    if (!await canDownload(userId)) {
      throw Exception('Premium subscription required for offline downloads');
    }

    try {
      // On web, just mark as downloaded (files are streamed, not stored)
      if (kIsWeb) {
        // Simulate download progress for UI
        if (onProgress != null) {
          for (double p = 0; p <= 1.0; p += 0.1) {
            await Future.delayed(const Duration(milliseconds: 100));
            onProgress(p);
          }
        }

        // Just save the ID
        final prefs = await SharedPreferences.getInstance();
        final downloadedIds = prefs.getStringList(_downloadedIdsKey) ?? [];
        if (!downloadedIds.contains(meditation.id)) {
          downloadedIds.add(meditation.id);
          await prefs.setStringList(_downloadedIdsKey, downloadedIds);
        }
        return;
      }

      // Mobile: actually download the file
      final path = await getLocalFilePath(meditation.id);

      await _dio.download(
        meditation.audioUrl,
        path,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // Save ID to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final downloadedIds = prefs.getStringList(_downloadedIdsKey) ?? [];
      if (!downloadedIds.contains(meditation.id)) {
        downloadedIds.add(meditation.id);
        await prefs.setStringList(_downloadedIdsKey, downloadedIds);
      }
    } catch (e) {
      debugPrint('Download error: $e');
      rethrow;
    }
  }

  /// Remove a downloaded track
  Future<void> removeTrack(String meditationId) async {
    try {
      final path = await getLocalFilePath(meditationId);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }

      final prefs = await SharedPreferences.getInstance();
      final downloadedIds = prefs.getStringList(_downloadedIdsKey) ?? [];
      downloadedIds.remove(meditationId);
      await prefs.setStringList(_downloadedIdsKey, downloadedIds);
    } catch (e) {
      debugPrint('Error removing track: $e');
    }
  }

  /// Get all downloaded meditation IDs
  Future<List<String>> getDownloadedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_downloadedIdsKey) ?? [];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Storage Management
  // ══════════════════════════════════════════════════════════════════════════

  /// Get total storage used by downloads (in bytes)
  Future<int> getTotalDownloadSize() async {
    try {
      final dir = await _getDownloadDirectory();
      final directory = Directory(dir);

      if (!await directory.exists()) return 0;

      int totalSize = 0;
      await for (final entity in directory.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('Error calculating download size: $e');
      return 0;
    }
  }

  /// Get file size for a specific meditation (in bytes)
  Future<int> getFileSize(String meditationId) async {
    try {
      final path = await getLocalFilePath(meditationId);
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting file size: $e');
      return 0;
    }
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    try {
      final dir = await _getDownloadDirectory();
      final directory = Directory(dir);

      if (await directory.exists()) {
        await directory.delete(recursive: true);
        await directory.create();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_downloadedIdsKey);
    } catch (e) {
      debugPrint('Error clearing downloads: $e');
    }
  }

  /// Format bytes to human-readable string
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
