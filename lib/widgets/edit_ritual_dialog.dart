import 'dart:io';
import 'package:image/image.dart' show decodeImage, copyResize, encodeJpg;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/meditation.dart';
import '../theme/app_theme.dart';

class EditRitualDialog extends StatefulWidget {
  final Meditation ritual;

  const EditRitualDialog({super.key, required this.ritual});

  @override
  State<EditRitualDialog> createState() => _EditRitualDialogState();
}

class _EditRitualDialogState extends State<EditRitualDialog> {
  late TextEditingController _titleController;
  late TextEditingController _minutesController;
  late TextEditingController _secondsController;
  late String _selectedCategory;
  late bool _isPremium;
  late bool _isAdRequired;

  PlatformFile? _newCoverImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.ritual.title);

    final totalSeconds =
        widget.ritual.durationSeconds ?? (widget.ritual.duration * 60);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    _minutesController = TextEditingController(text: minutes.toString());
    _secondsController = TextEditingController(text: seconds.toString());

    _selectedCategory = widget.ritual.category;
    _isPremium = widget.ritual.isPremium;
    _isAdRequired = widget.ritual.isAdRequired;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        final file = result.files.first;

        // Compression logic for web or small memory devices
        if (kIsWeb && file.bytes != null) {
          // Offload to compute to avoid UI jank if possible, but for simplicity:
          final img = decodeImage(file.bytes!);
          if (img != null) {
            // Resize to max 800px width
            final resized = copyResize(img, width: 800);
            // Compress
            final compressed = encodeJpg(resized, quality: 85);

            setState(() {
              _newCoverImage = PlatformFile(
                name: file.name,
                size: compressed.length,
                bytes: Uint8List.fromList(compressed),
              );
            });
            return;
          }
        }

        setState(() {
          _newCoverImage = file;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isUploading = true);

    try {
      String? newImageUrl;

      // Upload new image if selected
      if (_newCoverImage != null) {
        final imageRef = FirebaseStorage.instance.ref().child(
          'rituals/covers/${widget.ritual.id}/${_newCoverImage!.name}',
        );

        if (kIsWeb && _newCoverImage!.bytes != null) {
          await imageRef.putData(_newCoverImage!.bytes!);
        } else if (_newCoverImage!.path != null) {
          await imageRef.putFile(File(_newCoverImage!.path!));
        }
        newImageUrl = await imageRef.getDownloadURL();
      }

      final minutes = int.tryParse(_minutesController.text) ?? 0;
      final seconds = int.tryParse(_secondsController.text) ?? 0;
      final totalSeconds = (minutes * 60) + seconds;
      final durationMins = totalSeconds > 0
          ? (totalSeconds / 60).round()
          : 1; // Approx for legacy

      final updatedMeditation = widget.ritual.copyWith(
        title: _titleController.text.trim(),
        category: _selectedCategory,
        duration: durationMins > 0 ? durationMins : 1,
        durationSeconds: totalSeconds > 0 ? totalSeconds : 60,
        coverImage: newImageUrl ?? widget.ritual.coverImage,
        isPremium: _isPremium,
        isAdRequired: _isAdRequired,
      );

      Navigator.pop(context, updatedMeditation);
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating ritual: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.getCardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Ritual',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextColor(context),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              TextField(
                controller: _titleController,
                style: TextStyle(color: AppTheme.getTextColor(context)),
                decoration: _buildInputDecoration(context, 'Title'),
              ),
              const SizedBox(height: 16),

              // Duration (Minutes + Seconds)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppTheme.getTextColor(context)),
                      decoration: _buildInputDecoration(context, 'Minutes'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _secondsController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: AppTheme.getTextColor(context)),
                      decoration: _buildInputDecoration(context, 'Seconds'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                dropdownColor: AppTheme.getCardColor(context),
                style: TextStyle(color: AppTheme.getTextColor(context)),
                decoration: _buildInputDecoration(context, 'Category'),
                items: Meditation.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),

              // Switches
              SwitchListTile(
                title: Text(
                  'Premium',
                  style: TextStyle(color: AppTheme.getTextColor(context)),
                ),
                value: _isPremium,
                activeColor: AppTheme.getPrimary(context),
                onChanged: (val) => setState(() {
                  _isPremium = val;
                  if (val) _isAdRequired = false;
                }),
              ),
              SwitchListTile(
                title: Text(
                  'Ad Required',
                  style: TextStyle(color: AppTheme.getTextColor(context)),
                ),
                value: _isAdRequired,
                activeColor: Colors.blue,
                onChanged: (val) => setState(() {
                  _isAdRequired = val;
                  if (val) _isPremium = false;
                }),
              ),
              const SizedBox(height: 16),

              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.getBorderColor(context)),
                    image:
                        _newCoverImage != null ||
                            widget.ritual.coverImage.isNotEmpty
                        ? DecorationImage(
                            image: _newCoverImage != null
                                ? (kIsWeb
                                      ? MemoryImage(_newCoverImage!.bytes!)
                                      : FileImage(File(_newCoverImage!.path!))
                                            as ImageProvider)
                                : NetworkImage(widget.ritual.coverImage),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.3),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          color:
                              _newCoverImage != null ||
                                  widget.ritual.coverImage.isNotEmpty
                              ? Colors.white
                              : AppTheme.getMutedColor(context),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _newCoverImage != null
                              ? 'New Image Selected'
                              : 'Change Cover',
                          style: TextStyle(
                            color:
                                _newCoverImage != null ||
                                    widget.ritual.coverImage.isNotEmpty
                                ? Colors.white
                                : AppTheme.getMutedColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.getMutedColor(context)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.getPrimary(context),
                      foregroundColor: Colors.white,
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
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.getMutedColor(context)),
      filled: true,
      fillColor: AppTheme.getBackground(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
