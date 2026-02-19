import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:audioplayers/audioplayers.dart'; // REMOVED
import 'package:just_audio/just_audio.dart'; // ADDED
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/firestore_ritual.dart';

/// Interactive Ritual Button with:
/// - Breathing pulse animation
/// - Expand to 40% on tap
/// - Countdown timer
/// - Audio playback
/// - Confetti on completion
/// - "Ritual Complete" persistence
class RitualButton extends StatefulWidget {
  final FirestoreRitual ritual;

  const RitualButton({super.key, required this.ritual});

  @override
  State<RitualButton> createState() => _RitualButtonState();
}

class _RitualButtonState extends State<RitualButton>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _expandController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _expandAnimation;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer(); // just_audio

  // State
  bool _isExpanded = false;
  bool _isCompleted = false;
  bool _showConfetti = false;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkCompletionState();
  }

  void _initAnimations() {
    // Pulse animation (breathing effect)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Expand animation
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutBack,
    );
  }

  Future<void> _checkCompletionState() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCompletedDate = prefs.getString('ritual_completed_date');
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';

    if (lastCompletedDate == todayString) {
      setState(() => _isCompleted = true);
      _pulseController.stop();
    }
  }

  Future<void> _saveCompletionState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    await prefs.setString('ritual_completed_date', todayString);
  }

  void _startRitual() {
    if (_isCompleted) return;

    setState(() {
      _isExpanded = true;
      _remainingSeconds = widget.ritual.durationSeconds;
    });

    // Reset pulse controller to start fresh rhythm and keep it running
    _pulseController.forward(from: 0);
    _expandController.forward();

    // Start audio (if available)
    _playAudio();

    // Start countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _completeRitual();
      }
    });
  }

  Future<void> _playAudio() async {
    try {
      // In production, this would use the ritual's audio_url
      // For demo, we'll skip if URL is a local asset path
      if (widget.ritual.audioUrl.startsWith('http')) {
        await _audioPlayer.setUrl(widget.ritual.audioUrl);
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('Audio playback error: $e');
    }
  }

  void _completeRitual() {
    // Haptic feedback
    HapticFeedback.heavyImpact();

    // Stop audio
    _audioPlayer.stop();
    _pulseController.stop(); // Stop breathing when complete

    // Show confetti
    setState(() {
      _showConfetti = true;
      _isCompleted = true;
    });

    // Save completion state
    _saveCompletionState();

    // Hide confetti after animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showConfetti = false);
      }
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _expandController.dispose();
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final baseSize = 160.0;
    final expandedSize = screenHeight * 0.4;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Breathing Rings (Always visible unless completed)
        if (!_isCompleted)
          AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _expandController]),
            builder: (context, child) {
              // Calculate current button radius based on expansion manually to sync rings
              // We use baseSize logic similar to the button itself
              final currentSize = _isExpanded
                  ? baseSize +
                        (expandedSize - baseSize) * _expandAnimation.value
                  : baseSize;

              final currentRadius = currentSize / 2;

              return CustomPaint(
                painter: _RingsPainter(
                  progress: _pulseController.value,
                  color: AppTheme.isDark(context)
                      ? Colors.white
                      : AppTheme.getPrimary(context),
                  baseRadius: currentRadius,
                ),
                // Ensure drawing area is large enough for expanded rings
                size: Size(expandedSize * 2.5, expandedSize * 2.5),
              );
            },
          ),

        // Main button
        AnimatedBuilder(
          animation: Listenable.merge([_pulseAnimation, _expandAnimation]),
          builder: (context, child) {
            final size = _isExpanded
                ? baseSize + (expandedSize - baseSize) * _expandAnimation.value
                : baseSize * _pulseAnimation.value;

            return GestureDetector(
              onTap: _isExpanded || _isCompleted ? null : _startRitual,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: widget.ritual.coverImageUrl != null && !_isCompleted
                      ? DecorationImage(
                          image: NetworkImage(widget.ritual.coverImageUrl!),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.3),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                  gradient: widget.ritual.coverImageUrl == null || _isCompleted
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isCompleted
                              ? [AppTheme.sageGreen, AppTheme.sageGreenDark]
                              : [AppTheme.primary, const Color(0xFF6B8278)],
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isCompleted ? AppTheme.sageGreen : AppTheme.primary)
                              .withValues(alpha: 0.4),
                      blurRadius: 32,
                      spreadRadius: _isExpanded ? 8 : 0,
                    ),
                  ],
                ),
                child: Center(child: _buildButtonContent(size)),
              ),
            );
          },
        ),

        // Confetti overlay - sage green
        if (_showConfetti)
          Positioned.fill(child: IgnorePointer(child: _SageConfetti())),
      ],
    );
  }

  Widget _buildButtonContent(double size) {
    if (_isCompleted && !_isExpanded) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 40),
          const SizedBox(height: 8),
          Text(
            'Complete!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    if (_isExpanded) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Timer display
          Text(
            _formatTime(_remainingSeconds),
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isCompleted ? 'Ritual Complete' : 'Breathe...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!_isCompleted) ...[
            const SizedBox(height: 24),
            // Progress ring
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: 1 - (_remainingSeconds / widget.ritual.durationSeconds),
                strokeWidth: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ],
      );
    }

    // Default start state
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.ritual.coverImageUrl == null) ...[
          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 4),
          Text(
            'START',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ] else ...[
          // Clean minimal look for image cover
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white),
          ),
        ],
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double baseRadius;

  _RingsPainter({
    required this.progress,
    required this.color,
    required this.baseRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0; // Thicker lines

    // Use passed baseRadius
    final radiusBase = baseRadius;

    // Draw 3 breathing rings
    for (int i = 1; i <= 3; i++) {
      // Staggered offsets
      final ringOffset = 30.0 * i;

      // Dramatic expansion: Outer rings expand significantly more
      // Factor increased from 10 to 20 per index
      final breathExpansion = 20.0 * progress * i;

      final radius = radiusBase + ringOffset + breathExpansion;

      // Opacity Logic:
      // Increased opacity for better visibility (0.4 to 0.8 range)
      final opacity = (0.4 + (0.4 * progress)).clamp(0.0, 1.0);

      paint.color = color.withValues(alpha: opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.baseRadius != baseRadius;
  }
}

/// Custom sage green confetti animation
class _SageConfetti extends StatefulWidget {
  @override
  State<_SageConfetti> createState() => _SageConfettiState();
}

class _SageConfettiState extends State<_SageConfetti>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  // Sage green color palette
  static const List<Color> sageColors = [
    Color(0xFF8DA399), // Primary sage
    Color(0xFF7DA8A5), // Muted teal
    Color(0xFFC4D6C8), // Light sage
    Color(0xFF6B8278), // Dark sage
    Color(0xFFA8C5B8), // Soft sage
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Generate particles
    for (int i = 0; i < 50; i++) {
      _particles.add(
        _ConfettiParticle(
          x: _random.nextDouble(),
          y: -_random.nextDouble() * 0.3,
          speed: 0.3 + _random.nextDouble() * 0.4,
          size: 6 + _random.nextDouble() * 8,
          color: sageColors[_random.nextInt(sageColors.length)],
          rotation: _random.nextDouble() * pi * 2,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
        ),
      );
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  double speed;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final currentY = particle.y + particle.speed * progress * 2;
      final currentX =
          particle.x + sin(progress * pi * 4 + particle.rotation) * 0.05;
      final opacity = (1 - progress).clamp(0.0, 1.0);

      if (currentY > 1.2) continue;

      final paint = Paint()
        ..color = particle.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX * size.width, currentY * size.height);
      canvas.rotate(particle.rotation + particle.rotationSpeed * progress * 10);

      // Draw confetti shape (rectangle)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
