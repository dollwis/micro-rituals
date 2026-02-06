import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Neumorphic button with soft press effect
/// Updated for new design system
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  
  const NeumorphicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.width,
    this.height,
    this.backgroundColor,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppTheme.primary;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.width,
        height: widget.height ?? 56,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ]
              : [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.4),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ],
        ),
        transform: _isPressed 
            ? Matrix4.translationValues(0, 2, 0)
            : Matrix4.identity(),
        child: Center(child: widget.child),
      ),
    );
  }
}
