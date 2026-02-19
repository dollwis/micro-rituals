import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Storage Service for handling file uploads
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery
  Future<XFile?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // Resize to save bandwidth
        maxHeight: 512,
        imageQuality: 75, // Compress
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Upload profile picture for user
  /// Returns the download URL
  Future<String?> uploadProfilePicture(String uid, XFile xFile) async {
    try {
      final ref = _storage
          .ref()
          .child('users')
          .child(uid)
          .child('profile_picture.jpg');

      // Use putData with bytes for web compatibility
      final bytes = await xFile.readAsBytes();
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final uploadTask = ref.putData(bytes, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      return null;
    }
  }
}
