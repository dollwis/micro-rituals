import 'package:flutter/material.dart';
import '../services/audio_upload_service.dart';
import '../theme/app_theme.dart';

class AudioUploadDialog extends StatefulWidget {
  const AudioUploadDialog({super.key});

  @override
  State<AudioUploadDialog> createState() => _AudioUploadDialogState();
}

class _AudioUploadDialogState extends State<AudioUploadDialog> {
  final _audioUploadService = AudioUploadService();
  final _titleController = TextEditingController();

  String _selectedCategory = 'Focus';
  bool _isPremium = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _extractedDuration;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleUpload() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _extractedDuration = null;
    });

    try {
      await _audioUploadService.uploadNewMeditation(
        title: _titleController.text.trim(),
        category: _selectedCategory,
        isPremium: _isPremium,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        Navigator.pop(context, true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Audio uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Only check mounted if we are going to use context
      if (mounted) {
        setState(() => _isUploading = false);

        // Check if user cancelled (no file selected)
        if (e.toString().contains('No file selected')) {
          // Maybe don't show error snackbar for cancellation, or show info
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Upload cancelled')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme adaptation

    return Dialog(
      backgroundColor: AppTheme.getCardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Upload Meditation Audio',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextColor(context),
                ),
              ),
              const SizedBox(height: 24),

              // Title Input
              TextField(
                controller: _titleController,
                enabled: !_isUploading,
                style: TextStyle(color: AppTheme.getTextColor(context)),
                decoration: _buildInputDecoration('Title'),
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: AppTheme.getCardColor(context),
                style: TextStyle(color: AppTheme.getTextColor(context)),
                decoration: _buildInputDecoration('Category'),
                items:
                    [
                          'Sleep',
                          'Focus',
                          'Anxiety',
                          'Stress',
                          'Morning',
                          'Evening',
                          'Breathing',
                        ]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: _isUploading
                    ? null
                    : (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
              ),
              const SizedBox(height: 16),

              // Premium Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Premium Content',
                  style: TextStyle(color: AppTheme.getTextColor(context)),
                ),
                value: _isPremium,
                activeColor: AppTheme.getPrimary(context),
                onChanged: _isUploading
                    ? null
                    : (val) => setState(() => _isPremium = val),
              ),
              const SizedBox(height: 16),

              // Upload Progress
              if (_isUploading) ...[
                Column(
                  children: [
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: AppTheme.getPrimary(
                        context,
                      ).withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.getPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_uploadProgress * 100).toStringAsFixed(0)}% uploaded...',
                      style: TextStyle(
                        color: AppTheme.getMutedColor(context),
                        fontSize: 12,
                      ),
                    ),
                    if (_extractedDuration != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '✅ Duration: $_extractedDuration',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.getPrimary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.getPrimary(context).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppTheme.getPrimary(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Audio duration will be extracted automatically from the selected file.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getTextColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isUploading
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.getMutedColor(context)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _handleUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.getPrimary(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Pick File & Upload'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.getMutedColor(context)),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
