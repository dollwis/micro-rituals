import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
// import 'package:audioplayers/audioplayers.dart'; // REMOVED
import 'package:just_audio/just_audio.dart'; // ADDED
import 'package:uuid/uuid.dart';
import '../models/meditation.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'admin_manage_tab.dart';

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _uuid = const Uuid();
  final _firestoreService = FirestoreService();

  String _selectedCategory = Meditation.categories.first;
  bool _isPremium = false;
  bool _isAdRequired = false;

  // Audio file
  PlatformFile? _audioFile;
  Duration? _audioDuration;
  bool _calculatingDuration = false;

  // Cover image
  PlatformFile? _coverImageFile;

  bool _isUploading = false;
  String? _uploadStatus;

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _audioFile = result.files.first;
          _calculatingDuration = true;
          _audioDuration = null; // Reset
        });

        // Calculate duration
        final player = AudioPlayer();
        try {
          if (kIsWeb) {
            // Web duration logic skipped for now
          } else if (_audioFile!.path != null) {
            // just_audio way:
            await player.setFilePath(_audioFile!.path!);
            final duration =
                player.duration; // often available after setFilePath
            setState(() {
              _audioDuration = duration;
              if (duration != null) {
                _durationController.text = duration.inMinutes.toString();
              }
            });
          }
        } catch (e) {
          debugPrint('Error getting duration: $e');
        } finally {
          player.dispose();
          setState(() => _calculatingDuration = false);
        }
      }
    } catch (e) {
      debugPrint('Error picking audio: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _coverImageFile = result.files.first;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _uploadRitual() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audioFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an audio file')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatus = 'Starting upload...';
    });

    try {
      final ritualId = _uuid.v4();

      // 1. Upload Audio
      setState(() => _uploadStatus = 'Uploading audio...');
      final audioRef = FirebaseStorage.instance.ref().child(
        'rituals/audio/$ritualId/${_audioFile!.name}',
      );

      String audioUrl;
      if (kIsWeb && _audioFile!.bytes != null) {
        await audioRef.putData(_audioFile!.bytes!);
      } else if (_audioFile!.path != null) {
        await audioRef.putFile(File(_audioFile!.path!));
      } else {
        throw Exception('No audio data found');
      }
      audioUrl = await audioRef.getDownloadURL();

      // 2. Upload Cover Image (if selected)
      String? coverImageUrl;
      if (_coverImageFile != null) {
        setState(() => _uploadStatus = 'Uploading cover image...');
        final imageRef = FirebaseStorage.instance.ref().child(
          'rituals/covers/$ritualId/${_coverImageFile!.name}',
        );

        if (kIsWeb && _coverImageFile!.bytes != null) {
          await imageRef.putData(_coverImageFile!.bytes!);
        } else if (_coverImageFile!.path != null) {
          await imageRef.putFile(File(_coverImageFile!.path!));
        }
        coverImageUrl = await imageRef.getDownloadURL();
      }

      // 3. Create Firestore Entry
      setState(() => _uploadStatus = 'Saving meditation...');

      final durationMinutes =
          int.tryParse(_durationController.text) ??
          ((_audioDuration?.inSeconds ?? 0) ~/ 60);

      // Ensure at least 1 minute if there is any duration, or 0 if none
      final finalDuration = durationMinutes > 0 ? durationMinutes : 1;

      final meditation = Meditation(
        id: ritualId,
        title: _titleController.text.trim(),
        category: _selectedCategory,
        duration: finalDuration,
        audioUrl: audioUrl,
        coverImage: coverImageUrl ?? '',
        isPremium: _isPremium,
        isAdRequired: _isAdRequired,
      );

      await _firestoreService.addMeditation(meditation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ritual uploaded successfully!')),
        );
        // Reset form instead of popping to keep admin screen open
        _resetForm();
      }
    } catch (e) {
      setState(() {
        _uploadStatus = 'Error: $e';
        _isUploading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  void _resetForm() {
    setState(() {
      _titleController.clear();
      _durationController.clear();
      _selectedCategory = Meditation.categories.first;
      _isPremium = false;
      _isAdRequired = false;
      _audioFile = null;
      _coverImageFile = null;
      _audioDuration = null;
      _isUploading = false;
      _uploadStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Admin Console',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextColor(context),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.getTextColor(context)),
          bottom: TabBar(
            labelColor: AppTheme.getPrimary(context),
            unselectedLabelColor: AppTheme.getMutedColor(context),
            indicatorColor: AppTheme.getPrimary(context),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Upload New'),
              Tab(text: 'Manage Content'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildUploadTab(), const AdminManageTab()]),
      ),
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, 'RITUAL DETAILS'),
            const SizedBox(height: 16),

            // Title Input
            TextFormField(
              controller: _titleController,
              style: TextStyle(color: AppTheme.getTextColor(context)),
              decoration: _buildInputDecoration(context, 'Ritual Title'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Category Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: AppTheme.getCardColor(context),
                  style: TextStyle(color: AppTheme.getTextColor(context)),
                  items: Meditation.categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null)
                      setState(() => _selectedCategory = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader(context, 'MEDIA ASSETS'),
            const SizedBox(height: 16),

            // Audio Picker
            _buildFilePicker(
              context,
              label: 'Audio File',
              icon: Icons.audiotrack,
              file: _audioFile,
              onTap: _pickAudio,
              info: _audioDuration != null
                  ? '${(_audioDuration!.inMinutes).toString().padLeft(2, '0')}:${(_audioDuration!.inSeconds % 60).toString().padLeft(2, '0')}'
                  : _calculatingDuration
                  ? 'Calculating duration...'
                  : null,
            ),
            const SizedBox(height: 16),

            // Duration Input
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppTheme.getTextColor(context)),
              decoration: _buildInputDecoration(context, 'Duration (minutes)'),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (int.tryParse(value) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Image Picker
            _buildFilePicker(
              context,
              label: 'Cover Image',
              icon: Icons.image,
              file: _coverImageFile,
              onTap: _pickImage,
            ),
            const SizedBox(height: 32),

            _buildSectionHeader(context, 'SETTINGS'),
            const SizedBox(height: 16),

            // Premium Switch
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: AppTheme.getOrangeColor(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Premium Content',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isPremium,
                    onChanged: (val) => setState(() => _isPremium = val),
                    activeColor: AppTheme.getPrimary(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Watch Ad Switch
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.videocam, color: Colors.blue),
                      const SizedBox(width: 12),
                      Text(
                        'Watch Ad to Listen',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isAdRequired,
                    onChanged: (val) {
                      setState(() {
                        _isAdRequired = val;
                        // Optionally disable premium if ad is required
                        if (val) _isPremium = false;
                      });
                    },
                    activeColor: Colors.blue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Upload Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadRitual,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.getPrimary(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _uploadStatus ?? 'Uploading...',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      )
                    : const Text(
                        'Upload Metadata & Files',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: AppTheme.getMutedColor(context),
      ),
    );
  }

  Widget _buildFilePicker(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    PlatformFile? file,
    String? info,
  }) {
    final hasFile = file != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? AppTheme.getPrimary(context)
                : AppTheme.getBorderColor(context),
            width: hasFile ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasFile
                    ? AppTheme.getPrimary(context).withValues(alpha: 0.1)
                    : AppTheme.getIconBgColor(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hasFile ? Icons.check : icon,
                color: hasFile
                    ? AppTheme.getPrimary(context)
                    : AppTheme.getMutedColor(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? file.name : 'Select $label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: hasFile
                          ? AppTheme.getTextColor(context)
                          : AppTheme.getMutedColor(context),
                    ),
                  ),
                  if (info != null)
                    Text(
                      info,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.getPrimary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.getMutedColor(context)),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.getMutedColor(context)),
      filled: true,
      fillColor: AppTheme.getCardColor(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.getPrimary(context), width: 1.5),
      ),
    );
  }
}
