import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Provider for handling short audio previews (e.g. 10s clips)
/// Uses a separate just_audio AudioPlayer instance to run independently
/// from the main player, avoiding single-instance conflicts.
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

    // Configure for preview (respect silent mode, mix/duck others if needed)
    // But since we are pausing the main player, we just need standard playback.
    // However, for previews, 'ambient' or 'playback' is fine.
    // 'ambient' respects ringer switch (good for previews).
    _previewPlayer!.setAudioSource(
      AudioSource.uri(Uri.parse('')), // Placeholder to init session if needed
      preload: false,
    );
    // Note: just_audio usually handles session on play() based on defaults.
    // If we wanted specific category:
    // final session = await AudioSession.instance;
    // await session.configure(const AudioSessionConfiguration.music());

    // Listen to player state
    _previewPlayer!.playerStateStream.listen((state) {
      final playing = state.playing;
      if (_isPreviewPlaying != playing) {
        _isPreviewPlaying = playing;
        notifyListeners();
      }
    });

    // Auto-stop when preview ends naturally
    _previewPlayer!.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stopPreview();
      }
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

      // Set URL and play
      await _previewPlayer?.setUrl(url);
      await _previewPlayer?.play();

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
