import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meditation.dart';

class OfflineModeService {
  final Dio _dio = Dio();
  static const String _downloadedIdsKey = 'downloaded_meditation_ids';

  // Singleton pattern
  static final OfflineModeService _instance = OfflineModeService._internal();
  factory OfflineModeService() => _instance;
  OfflineModeService._internal();

  /// Get the local directory for storing audio files
  Future<String> _getDownloadDirectory() async {
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

  /// Check if a track is downloaded (and file exists)
  Future<bool> isTrackDownloaded(String meditationId) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedIds = prefs.getStringList(_downloadedIdsKey) ?? [];

    if (!downloadedIds.contains(meditationId)) return false;

    final path = await getLocalFilePath(meditationId);
    return File(path).exists();
  }

  /// Download a track
  Future<void> downloadTrack(
    Meditation meditation, {
    Function(double)? onProgress,
  }) async {
    try {
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
      print('Download error: $e');
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
      print('Error removing track: $e');
    }
  }

  /// Get all downloaded meditation IDs
  Future<List<String>> getDownloadedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_downloadedIdsKey) ?? [];
  }
}
