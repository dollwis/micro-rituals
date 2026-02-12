import 'package:flutter/material.dart';
import '../models/meditation.dart';
import '../services/offline_mode_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Screen for managing offline downloads
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final OfflineModeService _offlineService = OfflineModeService();
  final FirestoreService _firestoreService = FirestoreService();

  List<Meditation> _downloadedMeditations = [];
  int _totalSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() => _isLoading = true);

    try {
      // Get downloaded IDs
      final downloadedIds = await _offlineService.getDownloadedIds();

      // Get total size
      final size = await _offlineService.getTotalDownloadSize();

      // Fetch meditation details
      final meditations = <Meditation>[];
      for (final id in downloadedIds) {
        try {
          final meditation = await _firestoreService.getMeditationById(id);
          if (meditation != null) {
            meditations.add(meditation);
          }
        } catch (e) {
          print('Error loading meditation $id: $e');
        }
      }

      if (mounted) {
        setState(() {
          _downloadedMeditations = meditations;
          _totalSize = size;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading downloads: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearAllDownloads() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Clear All Downloads?',
          style: TextStyle(
            color: AppTheme.getTextColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will delete all downloaded files from your device. You can re-download them anytime.',
          style: TextStyle(color: AppTheme.getMutedColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.getMutedColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear All',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _offlineService.clearAllDownloads();
      await _loadDownloads();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All downloads cleared')));
      }
    }
  }

  Future<void> _deleteDownload(Meditation meditation) async {
    await _offlineService.removeTrack(meditation.id);
    await _loadDownloads();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removed ${meditation.title}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getCardColor(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Downloads',
          style: TextStyle(
            color: AppTheme.getTextColor(context),
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.getTextColor(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.getPrimary(context),
              ),
            )
          : _downloadedMeditations.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _downloadedMeditations.length,
                    itemBuilder: (context, index) {
                      return _buildDownloadItem(_downloadedMeditations[index]);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.getPrimary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storage_rounded,
                  color: AppTheme.getPrimary(context),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage Used',
                      style: TextStyle(
                        color: AppTheme.getMutedColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _offlineService.formatBytes(_totalSize),
                      style: TextStyle(
                        color: AppTheme.getTextColor(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_downloadedMeditations.length} ${_downloadedMeditations.length == 1 ? 'item' : 'items'}',
                style: TextStyle(
                  color: AppTheme.getMutedColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_downloadedMeditations.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearAllDownloads,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('Clear All Downloads'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDownloadItem(Meditation meditation) {
    return FutureBuilder<int>(
      future: _offlineService.getFileSize(meditation.id),
      builder: (context, snapshot) {
        final size = snapshot.data ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: meditation.coverImage.isNotEmpty
                  ? Image.network(
                      meditation.coverImage,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        width: 56,
                        height: 56,
                        color: AppTheme.getPrimary(
                          context,
                        ).withValues(alpha: 0.1),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: AppTheme.getPrimary(context),
                        ),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: AppTheme.getPrimary(
                        context,
                      ).withValues(alpha: 0.1),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: AppTheme.getPrimary(context),
                      ),
                    ),
            ),
            title: Text(
              meditation.title,
              style: TextStyle(
                color: AppTheme.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _offlineService.formatBytes(size),
              style: TextStyle(
                color: AppTheme.getMutedColor(context),
                fontSize: 14,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: Colors.red.withValues(alpha: 0.7),
              onPressed: () => _deleteDownload(meditation),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.getPrimary(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.download_rounded,
                size: 64,
                color: AppTheme.getPrimary(context),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Downloads Yet',
              style: TextStyle(
                color: AppTheme.getTextColor(context),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Download meditations for offline listening.\nLook for the download icon on meditation cards.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.getMutedColor(context),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
