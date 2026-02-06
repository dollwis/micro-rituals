import 'package:flutter/material.dart';
import '../models/meditation.dart';
import '../services/offline_mode_service.dart';

class DownloadIcon extends StatefulWidget {
  final Meditation meditation;
  final Color activeColor;
  final Color inactiveColor;

  const DownloadIcon({
    super.key,
    required this.meditation,
    required this.activeColor,
    required this.inactiveColor,
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
      // Download
      setState(() {
        _isDownloading = true;
        _progress = 0.0;
      });

      try {
        await _offlineService.downloadTrack(
          widget.meditation,
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
        );
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDownloading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: _progress,
          strokeWidth: 3,
          color: widget.activeColor,
        ),
      );
    }

    return IconButton(
      onPressed: _handleTap,
      icon: Icon(
        _isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
        color: _isDownloaded ? widget.activeColor : widget.inactiveColor,
      ),
    );
  }
}
