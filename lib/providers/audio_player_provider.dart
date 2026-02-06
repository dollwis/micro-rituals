import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/meditation.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/offline_mode_service.dart';

class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // State
  Meditation? _currentMeditation;
  List<Meditation> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLooping = false;
  double _volume = 1.0;

  // Stats tracking
  Timer? _statsTimer;
  int _listenSeconds = 0; // Total seconds listened in this session
  int _secondsSinceLastLog = 0; // Seconds accumulator for minute logging
  bool _hasMarkedComplete =
      false; // To ensure we only mark complete once per session
  String? _currentSessionId; // Unique ID to track discrete sessions

  // Getters
  Meditation? get currentMeditation => _currentMeditation;
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isLooping => _isLooping;
  double get volume => _volume;
  bool get hasNext => _queue.isNotEmpty && _currentIndex < _queue.length - 1;
  bool get hasPrevious => _queue.isNotEmpty && _currentIndex > 0;

  AudioPlayerProvider() {
    _initAudio();
  }

  void _initAudio() {
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _handleStatsTracking(_isPlaying);

      // Auto-advance logic
      if (state.processingState == ProcessingState.completed) {
        if (_isLooping) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        } else {
          // 100% Completion Haptics
          if (!_hapticsPlayed[100]!) {
            HapticFeedback.lightImpact();
            Future.delayed(const Duration(milliseconds: 150), () {
              HapticFeedback.lightImpact();
              Future.delayed(
                const Duration(milliseconds: 150),
                HapticFeedback.lightImpact,
              );
            });
            _hapticsPlayed[100] = true;
          }

          _isPlaying = false;
          _position = Duration.zero;
          notifyListeners();
        }
      }
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((newDuration) {
      if (newDuration != null) {
        _duration = newDuration;
        notifyListeners();
      }
    });

    _audioPlayer.positionStream.listen((newPosition) {
      _position = newPosition;
      notifyListeners();
    });
  }

  /// Start playing a new meditation.
  Future<void> play(Meditation meditation, {List<Meditation>? playlist}) async {
    // If playlist provided, update queue
    if (playlist != null) {
      _queue = playlist;
    } else if (_queue.isEmpty || !_queue.contains(meditation)) {
      _queue = [meditation];
    }

    // Update index
    _currentIndex = _queue.indexWhere((m) => m.id == meditation.id);
    if (_currentIndex == -1) {
      _queue = [meditation];
      _currentIndex = 0;
    }

    // If same meditation, just toggle play if paused
    if (_currentMeditation?.id == meditation.id) {
      if (!_isPlaying) {
        await resume();
      }
      return;
    }

    // Stop previous
    await _audioPlayer.stop();

    // Update State
    _currentMeditation = meditation;
    _currentSessionId = DateTime.now().toIso8601String();
    _hasMarkedComplete = false;
    _listenSeconds = 0;
    _secondsSinceLastLog = 0;
    _hapticsPlayed.updateAll((key, value) => false);
    _isPlaying = true;

    _statsTimer?.cancel();
    notifyListeners();

    try {
      if (meditation.audioUrl.isNotEmpty) {
        Uri? audioUri;

        if (kIsWeb) {
          audioUri = Uri.parse(meditation.audioUrl);
        } else {
          // Check for offline download
          final offlineService = OfflineModeService();
          if (await offlineService.isTrackDownloaded(meditation.id)) {
            final path = await offlineService.getLocalFilePath(meditation.id);
            audioUri = Uri.file(path);
            debugPrint('Playing from offline storage: $path');
          } else {
            audioUri = Uri.parse(meditation.audioUrl);
          }
        }

        // Just Audio Background Setup
        final mediaItem = MediaItem(
          id: meditation.id,
          album: meditation.category,
          title: meditation.title,
          artUri: meditation.coverImage.isNotEmpty
              ? Uri.parse(meditation.coverImage)
              : null,
        );

        if (kIsWeb || audioUri.scheme == 'file') {
          // Web or Local File
          await _audioPlayer.setAudioSource(AudioSource.uri(audioUri));
        } else {
          // Remote URL with Caching
          await _audioPlayer.setAudioSource(LockCachingAudioSource(audioUri));
        }

        await _audioPlayer.setVolume(_volume);
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentMeditation = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _statsTimer?.cancel();
    notifyListeners();
  }

  Future<void> rewind10() async {
    final newPos = _position - const Duration(seconds: 10);
    await seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  Future<void> forward10() async {
    final newPos = _position + const Duration(seconds: 10);
    await seek(newPos > _duration ? _duration : newPos);
  }

  void toggleLoop() {
    _isLooping = !_isLooping;
    if (_isLooping) {
      _audioPlayer.setLoopMode(LoopMode.one);
    } else {
      _audioPlayer.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  void setVolume(double value) {
    _volume = value;
    _audioPlayer.setVolume(value);
    notifyListeners();
  }

  Future<void> skipNext() async {
    if (hasNext) {
      await play(_queue[_currentIndex + 1]);
    }
  }

  Future<void> skipPrevious() async {
    if (_position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (hasPrevious) {
      await play(_queue[_currentIndex - 1]);
    } else {
      await seek(Duration.zero);
    }
  }

  void _handleStatsTracking(bool isPlaying) {
    _statsTimer?.cancel();
    if (isPlaying) {
      _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _listenSeconds++;
        _secondsSinceLastLog++;

        final durationSecs = _duration.inSeconds;

        if (_secondsSinceLastLog >= 60) {
          _logMinute();
          _secondsSinceLastLog = 0;
        }

        if (durationSecs > 0) {
          final progress = _position.inSeconds / durationSecs;

          // Haptics Logic
          if (!_hapticsPlayed[50]! && progress >= 0.5) {
            HapticFeedback.lightImpact();
            _hapticsPlayed[50] = true;
          }
          if (!_hapticsPlayed[75]! && progress >= 0.75) {
            HapticFeedback.lightImpact();
            Future.delayed(
              const Duration(milliseconds: 150),
              HapticFeedback.lightImpact,
            );
            _hapticsPlayed[75] = true;
          }
          // 100% handled in processingState.completed usually, but let's do close to end
          // Or we can rely on processingState
        }

        if (!_hasMarkedComplete && durationSecs > 0) {
          final threshold = durationSecs * 0.5;
          if (_listenSeconds >= threshold) {
            _markSessionComplete();
          }
        }
      });
    }
  }

  final Map<int, bool> _hapticsPlayed = {50: false, 75: false, 100: false};

  Future<void> _logMinute() async {
    final uid = _authService.currentUserId;
    if (uid != null && _currentMeditation != null) {
      await _firestoreService.logRitualMinutes(
        uid,
        1,
        ritualName: _currentMeditation!.title,
        coverImageUrl: _currentMeditation!.coverImage,
      );
      debugPrint('Logged 1 mindful minute (Provider)');
    }
  }

  Future<void> _markSessionComplete() async {
    final uid = _authService.currentUserId;
    if (uid != null) {
      _hasMarkedComplete = true;
      await _firestoreService.markRitualComplete(uid);
      debugPrint('Marked session complete (Provider)');
    }
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
