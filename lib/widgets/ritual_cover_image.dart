import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A wrapper around Image.network (Web) and CachedNetworkImage (Mobile)
/// to handle platform-specific image loading issues (e.g., CORS on Web).
class RitualCoverImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Duration? fadeInDuration;

  const RitualCoverImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fadeInDuration,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder(context);
    }

    Widget imageWidget;

    if (kIsWeb) {
      // Use standard Image.network on Web to leverage browser caching
      // and avoid CORS issues common with CachedNetworkImage's XHR requests.
      imageWidget = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: memCacheWidth, // Enable memory cache on web
        cacheHeight: memCacheHeight,
        loadingBuilder: placeholder != null
            ? (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return placeholder!(context, imageUrl);
              }
            : null,
        errorBuilder: (context, error, stackTrace) {
          if (errorWidget != null) {
            return errorWidget!(context, imageUrl, error);
          }
          return _buildErrorWidget(context);
        },
      );
    } else {
      // Use CachedNetworkImage on Mobile for persistent caching
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 500),
        placeholder: placeholder,
        errorWidget: errorWidget,
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (placeholder != null) {
      return placeholder!(context, imageUrl);
    }
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withValues(alpha: 0.1),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withValues(alpha: 0.1),
      child: const Icon(Icons.error_outline),
    );
  }
}
