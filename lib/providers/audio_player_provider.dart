import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/meditation.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/offline_mode_service.dart';

import '../providers/preview_audio_provider.dart';
import '../services/ad_service.dart';

/// ✅ OPTIMIZED Audio Player Provider
/// Key changes:
/// 1. Separate ValueNotifiers for granular updates
/// 2. Reduced timer frequency (1s → 5s)
/// 3. Separate haptics subscription
/// 4. Proper disposal
class AudioPlayerProvider extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // Dependency for mutual exclusion
  PreviewAudioProvider? _previewProvider;

  void setPreviewProvider(PreviewAudioProvider provider) {
    _previewProvider = provider;
  }

  // ✅ NEW: Granular notifiers for specific UI elements
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);

  // Keep these for backwards compatibility
  Meditation? _currentMeditation;
  List<Meditation> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLooping = true;
  bool _isShuffleMode = false;
  double _volume = 1.0;

  // Stats tracking
  Timer? _statsTimer;
  StreamSubscription<Duration>? _hapticsSubscription;
  int _listenSeconds = 0;
  int _secondsSinceLastLog = 0;
  bool _hasMarkedComplete = false;

  // Getters
  Meditation? get currentMeditation => _currentMeditation;
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isLooping => _isLooping;
  bool get isShuffleMode => _isShuffleMode;
  double get volume => _volume;
  bool get hasNext => _queue.isNotEmpty && _currentIndex < _queue.length - 1;
  bool get hasPrevious => _queue.isNotEmpty && _currentIndex > 0;

  AudioPlayerProvider() {
    _initAudio();
  }

  void _initAudio() {
    // ✅ Position updates - only notify position listeners
    _audioPlayer.positionStream.listen((newPosition) {
      _position = newPosition;
      positionNotifier.value = newPosition;
    }, onError: (e) => debugPrint('Position stream error: $e'));

    // ✅ Duration updates
    _audioPlayer.durationStream.listen((newDuration) {
      if (newDuration != null && _duration != newDuration) {
        _duration = newDuration;
        durationNotifier.value = newDuration;
      }
    }, onError: (e) => debugPrint('Duration stream error: $e'));

    // ✅ Player state updates
    _audioPlayer.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state.playing;
      isPlayingNotifier.value = state.playing;

      if (wasPlaying != _isPlaying) {
        notifyListeners();
      }

      _handleStatsTracking(_isPlaying);

      // Auto-advance is handled by ConcatenatingAudioSource now
      // We just need to handle completion of the *entire* playlist if not looping
      if (state.processingState == ProcessingState.completed) {
        // If loop mode is off and we finished the last item
        if (!_isLooping && !hasNext) {
          _handleCompletion();
        }
      }
    }, onError: (e) => debugPrint('Player state stream error: $e'));

    // ✅ Current Index Stream (for Playlist/Queue sync)
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && _queue.isNotEmpty && index < _queue.length) {
        if (_currentIndex != index) {
          _currentIndex = index;
          _currentMeditation = _queue[index];
          _resetStatsForNewTrack();
          notifyListeners();
        }
      }
    });

    // ✅ Loop Mode sync
    _audioPlayer.loopModeStream.listen((loopMode) {
      _isLooping = loopMode == LoopMode.all || loopMode == LoopMode.one;
      notifyListeners();
    });

    // ✅ Shuffle Mode sync
    _audioPlayer.shuffleModeEnabledStream.listen((shuffleEnabled) {
      _isShuffleMode = shuffleEnabled;
      notifyListeners();
    });
  }

  void _resetStatsForNewTrack() {
    _hasMarkedComplete = false;
    _listenSeconds = 0;
    _secondsSinceLastLog = 0;
    _hapticsPlayed.updateAll((key, value) => false);
    _statsTimer?.cancel();
    _hapticsSubscription?.cancel();
    if (_isPlaying) {
      _handleStatsTracking(true);
    }
  }

  void _handleCompletion() {
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
    isPlayingNotifier.value = false;
    _position = Duration.zero;
    positionNotifier.value = Duration.zero;
    notifyListeners();
  }

  /// Start playing a new meditation.
  Future<void> play(Meditation meditation, {List<Meditation>? playlist}) async {
    // 1. Update Internal Queue State
    if (playlist != null) {
      _queue = playlist;
    } else if (_queue.isEmpty || !_queue.contains(meditation)) {
      _queue = [meditation];
    }

    // Stop any active preview to prevent overlap
    _previewProvider?.stopPreview();

    final int targetIndex = _queue.indexWhere((m) => m.id == meditation.id);
    _currentIndex = targetIndex != -1 ? targetIndex : 0;
    _currentMeditation = _queue[_currentIndex];

    // 2. Reset visual state
    _isPlaying = true;
    isPlayingNotifier.value = true;
    _resetStatsForNewTrack();
    notifyListeners();

    try {
      // 3. Build Audio Sources for the ENTIRE queue
      final List<AudioSource> audioSources = [];
      final offlineService = OfflineModeService();

      for (var m in _queue) {
        if (m.audioUrl.isEmpty) continue;

        Uri audioUri;
        if (kIsWeb) {
          audioUri = Uri.parse(m.audioUrl);
        } else {
          if (await offlineService.isTrackDownloaded(m.id)) {
            final path = await offlineService.getLocalFilePath(m.id);
            audioUri = Uri.file(path);
          } else {
            audioUri = Uri.parse(m.audioUrl);
          }
        }

        // Media Item for Notification
        final mediaItem = MediaItem(
          id: m.id,
          album: m.category,
          title: m.title,
          artUri: m.coverImage.isNotEmpty ? Uri.parse(m.coverImage) : null,
        );

        if (kIsWeb || audioUri.scheme == 'file') {
          audioSources.add(AudioSource.uri(audioUri, tag: mediaItem));
        } else {
          audioSources.add(LockCachingAudioSource(audioUri, tag: mediaItem));
        }
      }

      // 4. Set Source to Player (Concatenating)
      // Note: Recreating the source every time 'play' is called ensures sync.
      // Optimization: We could check if current source is same playlist.
      await _audioPlayer.setAudioSource(
        ConcatenatingAudioSource(children: audioSources),
        initialIndex: _currentIndex,
      );

      // 5. Configure Player
      await _audioPlayer.setVolume(_volume);
      // Default to LoopMode.off for playlist, allowing auto-advance.
      // Or user preference. If we want auto-advance, use LoopMode.off (stops at end of list)
      // or LoopMode.all (loops list).
      // Existing logic had `_isLooping` default true. Let's respect `_isLooping`.
      // If `_isLooping` is true, we probably want `LoopMode.all` for a playlist?
      // Or `LoopMode.one`?
      // User request implies "next/previous", so likely expects a playlist flow.
      await _audioPlayer.setLoopMode(_isLooping ? LoopMode.all : LoopMode.off);

      // 6. Play
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _isPlaying = false;
      isPlayingNotifier.value = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    // Optimistic UI update
    if (_isPlaying) {
      isPlayingNotifier.value = false;
      _isPlaying = false;
      notifyListeners();
    }
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    _previewProvider?.stopPreview();
    // Optimistic UI update
    if (!_isPlaying) {
      isPlayingNotifier.value = true;
      _isPlaying = true;
      notifyListeners();
    }
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
    isPlayingNotifier.value = false;
    _position = Duration.zero;
    positionNotifier.value = Duration.zero;
    _duration = Duration.zero;
    durationNotifier.value = Duration.zero;
    _statsTimer?.cancel();
    _hapticsSubscription?.cancel();
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

  Future<void> playRandom() async {
    try {
      final meditations = await _firestoreService.getAllMeditations();
      if (meditations.isEmpty) return;

      final random = Random();
      Meditation nextMeditation;

      if (meditations.length > 1 && _currentMeditation != null) {
        // Try to pick a different one
        do {
          nextMeditation = meditations[random.nextInt(meditations.length)];
        } while (nextMeditation.id == _currentMeditation!.id);
      } else {
        nextMeditation = meditations[random.nextInt(meditations.length)];
      }

      await play(nextMeditation);
    } catch (e) {
      debugPrint('Error playing random track: $e');
    }
  }

  void setVolume(double value) {
    _volume = value;
    _audioPlayer.setVolume(value);
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffleMode = !_isShuffleMode;
    _audioPlayer.setShuffleModeEnabled(_isShuffleMode);
    notifyListeners();
  }

  Future<void> skipNext() async {
    try {
      if (_isShuffleMode) {
        // If "Global Shuffle" behavior is desired, we keep playRandom()
        // But for notification compat, we need the queue to be the random list.
        // For now, let's trust the queue is what the user wants.
        // If the user wants global shuffle, they should start a "Random" playlist.
        await _audioPlayer.seekToNext();
      } else if (_audioPlayer.hasNext) {
        await _audioPlayer.seekToNext();
      }
    } catch (e) {
      debugPrint('Error skipping next: $e');
    }
  }

  Future<void> skipPrevious() async {
    try {
      if (_position.inSeconds > 3) {
        await seek(Duration.zero);
        return;
      }
      if (_audioPlayer.hasPrevious) {
        await _audioPlayer.seekToPrevious();
      } else {
        await seek(Duration.zero);
      }
    } catch (e) {
      debugPrint('Error skipping previous: $e');
    }
  }

  /// ✅ OPTIMIZED: Reduced frequency and separated concerns
  void _handleStatsTracking(bool isPlaying) {
    _statsTimer?.cancel();
    _hapticsSubscription?.cancel();

    if (isPlaying) {
      // ✅ Reduced from 1s to 5s - 80% less CPU usage
      _statsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _listenSeconds += 5;
        _secondsSinceLastLog += 5;

        if (_secondsSinceLastLog >= 60) {
          _logMinute();
          _secondsSinceLastLog = 0;
        }

        if (!_hasMarkedComplete && _duration.inSeconds > 0) {
          final threshold = _duration.inSeconds * 0.5;
          if (_listenSeconds >= threshold) {
            _markSessionComplete();
          }
        }

        // Auto-skip logic: If shuffle is on and listening for 30+ mins
        if (_isShuffleMode && _listenSeconds >= 1800) {
          debugPrint('Auto-skipping after 30 mins');
          playRandom();
        }
      });

      // ✅ Separate subscription for haptics (more responsive)
      _hapticsSubscription = _audioPlayer.positionStream.listen((position) {
        if (_duration.inSeconds == 0) return;

        final progress = position.inSeconds / _duration.inSeconds;

        // Haptics at 50%
        if (!_hapticsPlayed[50]! && progress >= 0.5) {
          HapticFeedback.lightImpact();
          _hapticsPlayed[50] = true;
        }

        // Haptics at 75%
        if (!_hapticsPlayed[75]! && progress >= 0.75) {
          HapticFeedback.lightImpact();
          Future.delayed(const Duration(milliseconds: 150), () {
            HapticFeedback.lightImpact();
          });
          _hapticsPlayed[75] = true;
        }
      });
    }
  }

  final Map<int, bool> _hapticsPlayed = {50: false, 75: false, 100: false};

  Future<void> _logMinute() async {
    final uid = _authService.currentUserId;
    if (uid != null && _currentMeditation != null) {
      // ✅ Don't await - fire and forget to avoid blocking
      _firestoreService
          .logRitualMinutes(
            uid,
            1,
            ritualName: _currentMeditation!.title,
            coverImageUrl: _currentMeditation!.coverImage,
          )
          .catchError((e) {
            debugPrint('Error logging minute: $e');
          });
      debugPrint('Logged 1 mindful minute (Provider)');
      // Track for Ad Service
      AdService().trackListeningTime();
    }
  }

  Future<void> _markSessionComplete() async {
    final uid = _authService.currentUserId;
    if (uid != null) {
      _hasMarkedComplete = true;
      // ✅ Don't await - fire and forget
      _firestoreService.markRitualComplete(uid).catchError((e) {
        debugPrint('Error marking complete: $e');
      });
      debugPrint('Marked session complete (Provider)');
    }
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _hapticsSubscription?.cancel();
    positionNotifier.dispose();
    durationNotifier.dispose();
    isPlayingNotifier.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
