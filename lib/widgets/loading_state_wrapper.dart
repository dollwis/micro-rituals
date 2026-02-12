import 'package:flutter/material.dart';

/// Reusable loading state wrapper that displays a loading indicator
/// over content when isLoading is true.
///
/// This standardizes loading UI across the app and eliminates
/// repeated CircularProgressIndicator boilerplate.
class LoadingStateWrapper extends StatelessWidget {
  /// The child widget to display when not loading
  final Widget child;

  /// Whether the loading indicator should be shown
  final bool isLoading;

  /// Optional custom loading widget. Defaults to CircularProgressIndicator
  final Widget? loadingWidget;

  /// Background color of the loading overlay
  final Color? overlayColor;

  /// Whether to show the child widget behind the loading overlay
  /// If false, only the loading widget is shown
  final bool showChildWhileLoading;

  const LoadingStateWrapper({
    super.key,
    required this.child,
    required this.isLoading,
    this.loadingWidget,
    this.overlayColor,
    this.showChildWhileLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return child;
    }

    if (!showChildWhileLoading) {
      return Center(child: loadingWidget ?? const CircularProgressIndicator());
    }

    // Show overlay on top of child
    return Stack(
      children: [
        child,
        Container(
          color: overlayColor ?? Colors.black54,
          child: Center(
            child: loadingWidget ?? const CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }
}
