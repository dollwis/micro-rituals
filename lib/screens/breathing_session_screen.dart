import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meditation.dart';
import '../providers/audio_player_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/ritual_window_service.dart';
import '../providers/preview_audio_provider.dart';
import '../theme/app_theme.dart';

/// Breathing Session Screen - Matches reference design
/// Features: Sage green layered circles, 8s breathe animation, dynamic text
class BreathingSessionScreen extends StatefulWidget {
  final Meditation ritual;

  const BreathingSessionScreen({super.key, required this.ritual});

  @override
  State<BreathingSessionScreen> createState() => _BreathingSessionScreenState();
}

class _BreathingSessionScreenState extends State<BreathingSessionScreen>
    with TickerProviderStateMixin {
  // Animation controller - 8 second cycle
  late AnimationController _breatheController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  // State
  bool _isActive = false;
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _showConfetti = false;
  int _currentStep = 0; // 0 = ready, 1 = breathing, 2 = complete
  Timer? _countdownTimer;

  // Use ValueNotifier for timer to avoid rebuilding entire widget tree
  final ValueNotifier<int> _remainingSecondsNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkCompletionState();
  }

  void _initAnimations() {
    // 8-second breathing cycle
    _breatheController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    // Scale: 0.85 → 1.1 → 0.85 with smoother cubic easing
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.85,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.1,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_breatheController);

    // Opacity: 0.8 → 1.0 → 0.8 with smoother easing
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.8,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.8,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_breatheController);
  }

  Future<void> _checkCompletionState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCompletedDate = prefs.getString('ritual_completed_date');
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    if (lastCompletedDate == todayString) {
      setState(() {
        _isCompleted = true;
        _currentStep = 2;
      });
    }
  }

  Future<void> _saveCompletionState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    await prefs.setString('ritual_completed_date', todayString);
  }

  void _startSession() {
    if (_isCompleted) return;

    // Stop main audio player if playing
    try {
      final mainPlayer = Provider.of<AudioPlayerProvider>(
        context,
        listen: false,
      );
      mainPlayer.stop(); // Stop main player so it doesn't overlap

      final previewPlayer = Provider.of<PreviewAudioProvider>(
        context,
        listen: false,
      );
      previewPlayer.stopPreview(); // Stop any active previews
    } catch (e) {
      debugPrint('Error stopping other players: $e');
    }

    setState(() {
      _isActive = true;
      _currentStep = 1;
    });

    // Initialize timer value
    _remainingSecondsNotifier.value = 10; // Modified for testing: 10 seconds

    _breatheController.repeat();
    _playAudio();

    // Use ValueNotifier instead of setState to avoid rebuilding entire widget
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSecondsNotifier.value--;

      if (_remainingSecondsNotifier.value <= 0) {
        timer.cancel();
        _completeSession();
      }
    });
  }

  void _togglePause() {
    if (_isPaused) {
      // Resume
      setState(() => _isPaused = false);
      _breatheController.repeat();
      _audioPlayer.play();

      // Restart countdown using ValueNotifier
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _remainingSecondsNotifier.value--;
        if (_remainingSecondsNotifier.value <= 0) {
          timer.cancel();
          _completeSession();
        }
      });
    } else {
      // Pause
      setState(() => _isPaused = true);
      _breatheController.stop();
      _audioPlayer.pause();
      _countdownTimer?.cancel();
    }
  }

  Future<void> _playAudio() async {
    if (widget.ritual.audioUrl.isEmpty) {
      debugPrint('Audio URL is empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No audio URL found for this ritual'),
          ),
        );
      }
      return;
    }

    try {
      debugPrint('Setting URL source: ${widget.ritual.audioUrl}');
      await _audioPlayer.setVolume(1.0); // Ensure volume is up

      // Create MediaItem for background playback support
      final mediaItem = MediaItem(
        id: widget.ritual.id,
        album: widget.ritual.category,
        title: widget.ritual.title,
        artUri: widget.ritual.coverImage.isNotEmpty
            ? Uri.tryParse(widget.ritual.coverImage)
            : null,
      );

      // Verify URL format
      Uri audioUri;
      // Handle local file paths if necessary, or just try parsing
      audioUri = Uri.parse(widget.ritual.audioUrl);

      await _audioPlayer.setAudioSource(
        AudioSource.uri(audioUri, tag: mediaItem),
      );

      debugPrint('Playing...');
      await _audioPlayer.play();
      debugPrint('Playback started');
    } catch (e) {
      debugPrint('Audio error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Playback failed: $e')));
      }
    }
  }

  void _completeSession() {
    HapticFeedback.heavyImpact();
    _audioPlayer.stop();
    _breatheController.stop();

    setState(() {
      _showConfetti = false; // Disabled confetti for testing
      _isCompleted = true;
      _currentStep = 2;
    });

    _saveCompletionState();
    _recordToFirestore();

    // Mark the current window as completed
    RitualWindowService.markCurrentWindowCompleted();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showConfetti = false);
    });
  }

  Future<void> _recordToFirestore() async {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final uid = authService.currentUserId;

    if (uid != null) {
      await firestoreService.recordCompletion(
        uid,
        10, // Modified for testing: 10 seconds
        ritualName: widget.ritual.title,
        source: 'ritual_window',
      );
    }
  }

  String get _breathePhase {
    if (!_isActive || _isPaused) return 'Tap to begin';
    final phase = (_breatheController.value * 2).floor() % 2;
    return phase == 0 ? 'Breathe in' : 'Breathe out';
  }

  String get _instructionText {
    if (_isCompleted) return 'You\'ve completed today\'s ritual. Great work!';
    if (!_isActive) return 'Find a comfortable position and relax.';
    if (_isPaused) return 'Take your time. Resume when ready.';
    final phase = (_breatheController.value * 2).floor() % 2;
    return phase == 0
        ? 'Allow your lungs to expand fully, finding space within.'
        : 'Release slowly, letting go of any tension.';
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _countdownTimer?.cancel();
    _countdownTimer = null; // Ensure timer is fully cleared
    _audioPlayer.dispose();
    _remainingSecondsNotifier.dispose(); // Dispose ValueNotifier
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top nav with close button
                _buildTopNav(),

                // Main breathing area
                Expanded(child: _buildBreathingArea()),

                // Bottom indicators
                _buildBottomArea(),
              ],
            ),

            // Confetti overlay
            if (_showConfetti)
              Positioned.fill(
                child: IgnorePointer(
                  child: Lottie.network(
                    'https://assets3.lottiefiles.com/packages/lf20_u4yrau.json',
                    repeat: false,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Semantics(
            label: 'Close breathing session',
            button: true,
            hint: 'Double tap to exit and return to previous screen',
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.getSageColor(context).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: AppTheme.getTextColor(context),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathingArea() {
    // Check for reduced motion accessibility preference
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Cache colors outside the builder to avoid per-frame allocation
    final sageColor = AppTheme.getSageColor(context);
    final textColor = AppTheme.getTextColor(context);

    return Semantics(
      label: _isCompleted
          ? 'Breathing session completed'
          : _isActive
          ? 'Breathing session in progress. ${_breathePhase}. $_instructionText'
          : 'Start breathing session',
      button: !_isActive && !_isCompleted,
      hint: !_isActive && !_isCompleted
          ? 'Double tap to begin 10 minute breathing session'
          : null,
      liveRegion: _isActive,
      child: GestureDetector(
        onTap: _isActive || _isCompleted ? null : _startSession,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Breathing circles - decorative, excluded from semantics
            ExcludeSemantics(
              child: SizedBox(
                width: 320,
                height: 320,
                // RepaintBoundary isolates animation repaints from rest of tree
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _breatheController,
                    builder: (context, child) {
                      final scale = _isActive && !reduceMotion
                          ? _scaleAnimation.value
                          : 0.85;
                      final opacity = _isActive && !reduceMotion
                          ? _opacityAnimation.value
                          : 0.8;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          if (!reduceMotion)
                            Transform.scale(
                              scale: scale * 1.1,
                              alignment: Alignment.center,
                              child: Container(
                                width: 320,
                                height: 320,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: sageColor.withValues(
                                    alpha: 0.1 * opacity,
                                  ),
                                ),
                              ),
                            ),
                          // Middle blur ring
                          if (!reduceMotion)
                            Transform.scale(
                              scale: scale * 1.05,
                              alignment: Alignment.center,
                              child: Container(
                                width: 256,
                                height: 256,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: sageColor.withValues(
                                    alpha: 0.2 * opacity,
                                  ),
                                ),
                              ),
                            ),
                          // Main breathing circle
                          Transform.scale(
                            scale: reduceMotion ? 1.0 : scale,
                            alignment: Alignment.center,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sageColor.withValues(alpha: 0.3),
                              ),
                              child: Center(
                                // Inner circle
                                child: Container(
                                  width: 238,
                                  height: 238,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: sageColor.withValues(
                                      alpha: reduceMotion ? 0.9 : 0.9 * opacity,
                                    ),
                                    // Shadow on inner circle only (smaller, cheaper)
                                    boxShadow: [
                                      BoxShadow(
                                        color: sageColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: _isCompleted
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 64,
                                        )
                                      : _isActive
                                      ? _buildTimer()
                                      : Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                          size: 64,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Text content - fixed height to prevent layout shift
            // Uses AnimatedBuilder only for phase text changes (cheap rebuild)
            SizedBox(
              height: 120,
              child: AnimatedBuilder(
                animation: _breatheController,
                builder: (context, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        _isCompleted ? 'Complete!' : _breathePhase,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w300,
                          color: textColor,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          _instructionText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: textColor.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return ValueListenableBuilder<int>(
      valueListenable: _remainingSecondsNotifier,
      builder: (context, remainingSeconds, child) {
        final mins = remainingSeconds ~/ 60;
        final secs = remainingSeconds % 60;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 48),
      child: Column(
        children: [
          // Step indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _currentStep
                      ? AppTheme.getSageColor(context)
                      : AppTheme.getSageColor(context).withValues(alpha: 0.3),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Pause button (only during active session)
          if (_isActive && !_isCompleted)
            Semantics(
              label: _isPaused
                  ? 'Resume breathing session'
                  : 'Pause breathing session',
              button: true,
              hint: _isPaused
                  ? 'Double tap to resume breathing exercise'
                  : 'Double tap to pause breathing exercise',
              child: GestureDetector(
                onTap: _togglePause,
                child: Text(
                  _isPaused ? 'RESUME SESSION' : 'PAUSE SESSION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.getPrimary(context),
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
