import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CacheCleanupService {
  static const int _maxCacheSize = 500 * 1024 * 1024; // 500 MB

  /// Run cache cleanup
  Future<void> cleanCache() async {
    if (kIsWeb) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/just_audio_cache');

      if (!await cacheDir.exists()) return;

      final List<FileSystemEntity> files = cacheDir.listSync();
      int totalSize = 0;
      final List<File> audioFiles = [];

      for (var entity in files) {
        if (entity is File) {
          totalSize += await entity.length();
          audioFiles.add(entity);
        }
      }

      debugPrint(
        'Current Audio Cache Size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      if (totalSize > _maxCacheSize) {
        debugPrint('Cache exceeds limit. Cleaning up...');

        // Sort by modification time (oldest first)
        audioFiles.sort(
          (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
        );

        for (var file in audioFiles) {
          if (totalSize <= _maxCacheSize) break;

          final fileSize = await file.length();
          await file.delete();
          totalSize -= fileSize;
          debugPrint('Deleted cached file: ${file.path}');
        }

        debugPrint(
          'Cache cleanup complete. New Size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB',
        );
      }
    } catch (e) {
      debugPrint('Error cleaning cache: $e');
    }
  }
}
