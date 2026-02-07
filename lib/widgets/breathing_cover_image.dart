import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class BreathingCoverImage extends StatefulWidget {
  final String? imageUrl;
  final double size;
  final bool isPlaying;

  const BreathingCoverImage({
    super.key,
    required this.imageUrl,
    this.size = 200,
    this.isPlaying = false,
  });

  @override
  State<BreathingCoverImage> createState() => _BreathingCoverImageState();
}

class _BreathingCoverImageState extends State<BreathingCoverImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    if (widget.isPlaying) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(BreathingCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        // Removed reset() so it stays in place
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 1.4, // Decreased from 1.5
      height: widget.size * 1.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Breathing Rings
          if (widget.isPlaying)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RingsPainter(
                      progress: _pulseController.value,
                      color: AppTheme.isDark(context)
                          ? Colors.white
                          : AppTheme.getPrimary(context),
                      baseRadius: widget.size / 2,
                    ),
                    size: Size(widget.size * 1.4, widget.size * 1.4),
                  );
                },
              ),
            ),

          // Main Image Circle
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                  ? DecorationImage(
                      image: ResizeImage(
                        CachedNetworkImageProvider(widget.imageUrl!),
                        width: (widget.size * 2.5)
                            .toInt(), // Optimization: Decode closer to display size
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: widget.imageUrl == null || widget.imageUrl!.isEmpty
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.getLavenderColor(context),
                        AppTheme.getPrimary(context).withValues(alpha: 0.2),
                      ],
                    )
                  : null,
              border: Border.all(
                color: AppTheme.isDark(context)
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.getPrimary(context).withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: widget.imageUrl == null || widget.imageUrl!.isEmpty
                ? Icon(
                    Icons.spa,
                    size: widget.size * 0.4,
                    color: AppTheme.getPrimary(context).withValues(alpha: 0.8),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double baseRadius;
  final Paint _paint = Paint(); // Cache Paint object

  _RingsPainter({
    required this.progress,
    required this.color,
    required this.baseRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    _paint
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5; // Thinner lines

    for (int i = 1; i <= 3; i++) {
      final ringOffset = 10.0 * i; // Much tighter (was 20)
      final breathExpansion = 8.0 * progress * i; // Reduced breath (was 15)

      final radius = baseRadius + ringOffset + breathExpansion;

      // Opacity Logic
      final opacity = (0.2 + (0.5 * progress)).clamp(0.0, 0.8);

      _paint.color = color.withValues(alpha: opacity);

      canvas.drawCircle(center, radius, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.baseRadius != baseRadius;
  }
}
