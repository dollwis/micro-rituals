import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Provider for handling short audio previews (e.g. 10s clips)
/// Uses 'audioplayers' package to run independently from the main 'just_audio' player
/// to avoid "single player instance" conflicts with just_audio_background.
class PreviewAudioProvider extends ChangeNotifier {
  AudioPlayer? _previewPlayer;
  String? _currentPreviewUrl;
  bool _isPreviewPlaying = false;
  Timer? _previewTimer;

  bool get isPreviewPlaying => _isPreviewPlaying;
  String? get currentPreviewUrl => _currentPreviewUrl;

  PreviewAudioProvider() {
    _initPreviewPlayer();
  }

  void _initPreviewPlayer() {
    _previewPlayer = AudioPlayer();

    // Configure audio context if needed (default is usually fine for previews)
    // _previewPlayer!.setAudioContext(...)

    // Listen to player state
    _previewPlayer!.onPlayerStateChanged.listen((state) {
      _isPreviewPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    // Auto-stop when preview ends naturally
    _previewPlayer!.onPlayerComplete.listen((_) {
      stopPreview();
    });
  }

  Future<void> playPreview(
    String url, {
    Duration duration = const Duration(seconds: 15),
  }) async {
    try {
      // If same preview is playing, pause it
      if (_currentPreviewUrl == url && _isPreviewPlaying) {
        await pausePreview();
        return;
      }

      // Stop any existing preview
      await stopPreview();

      _currentPreviewUrl = url;

      // Play using UrlSource
      await _previewPlayer?.play(UrlSource(url));

      // Auto-stop after duration
      _previewTimer?.cancel();
      _previewTimer = Timer(duration, () {
        stopPreview();
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error playing preview: $e');
      stopPreview();
    }
  }

  Future<void> pausePreview() async {
    // Optimistic UI Update
    _isPreviewPlaying = false;
    notifyListeners();

    try {
      await _previewPlayer?.pause();
      _previewTimer?.cancel();
    } catch (e) {
      debugPrint('Error pausing preview: $e');
    }
  }

  Future<void> stopPreview() async {
    // Optimistic UI Update
    _isPreviewPlaying = false;
    _currentPreviewUrl = null;
    notifyListeners();

    try {
      _previewTimer?.cancel();
      await _previewPlayer?.stop();
    } catch (e) {
      debugPrint('Error stopping preview: $e');
    }
  }

  bool isPlayingUrl(String url) {
    return _currentPreviewUrl == url && _isPreviewPlaying;
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _previewPlayer?.dispose();
    super.dispose();
  }
}
