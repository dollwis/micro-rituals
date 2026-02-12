import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meditation.dart';
import '../services/offline_mode_service.dart';
import '../providers/user_stats_provider.dart';
import './premium_required_dialog.dart';

class DownloadIcon extends StatefulWidget {
  final Meditation meditation;
  final Color activeColor;
  final Color inactiveColor;
  final double? size;

  const DownloadIcon({
    super.key,
    required this.meditation,
    required this.activeColor,
    required this.inactiveColor,
    this.size,
  });

  @override
  State<DownloadIcon> createState() => _DownloadIconState();
}

class _DownloadIconState extends State<DownloadIcon> {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _progress = 0.0;
  final OfflineModeService _offlineService = OfflineModeService();

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final downloaded = await _offlineService.isTrackDownloaded(
      widget.meditation.id,
    );
    if (mounted) {
      setState(() => _isDownloaded = downloaded);
    }
  }

  Future<void> _handleTap() async {
    if (_isDownloading) return;

    if (_isDownloaded) {
      // Confirm remove
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Download?'),
          content: const Text('This will delete the file from your device.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _offlineService.removeTrack(widget.meditation.id);
        if (mounted) setState(() => _isDownloaded = false);
      }
    } else {
      // Check premium status before downloading
      final user = Provider.of<UserStatsProvider>(
        context,
        listen: false,
      ).userStats;
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        // Guest user - prompt to sign in with dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sign In Required'),
              content: const Text(
                'Please sign in to download meditations for offline listening.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text('Sign In'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (user == null || !user.hasActiveSubscription) {
        // Show premium required dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) =>
                const PremiumRequiredDialog(feature: 'offline downloads'),
          );
        }
        return;
      }

      // Download
      setState(() {
        _isDownloading = true;
        _progress = 0.0;
      });

      try {
        await _offlineService.downloadTrack(
          widget.meditation,
          userId,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Download complete')));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDownloading = false);
          final message = e.toString().contains('Premium')
              ? 'Premium subscription required'
              : 'Download failed: $e';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.size ?? 24.0;

    if (_isDownloading) {
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          value: _progress,
          strokeWidth: 3,
          color: widget.activeColor,
        ),
      );
    }

    return IconButton(
      onPressed: _handleTap,
      iconSize: iconSize,
      padding: const EdgeInsets.all(8), // Larger tap target for web
      constraints: const BoxConstraints(), // Remove default constraints
      icon: Icon(
        _isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
        color: _isDownloaded ? widget.activeColor : widget.inactiveColor,
      ),
      tooltip: _isDownloaded ? 'Remove download' : 'Download',
    );
  }
}
