import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';
import '../models/firestore_user.dart';
import 'login_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  FirestoreUser? _userStats;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initUserData();
  }

  Future<void> _initUserData() async {
    final user = _authService.currentUser;
    final uid = _authService.currentUserId;

    if (uid == null) return;

    // 1. Set defaults from Auth initially
    final displayName = user?.displayName ?? 'Elena Vance';
    final names = displayName.split(' ');

    _firstNameController.text = names.isNotEmpty ? names.first : 'Elena';
    _lastNameController.text = names.length > 1
        ? names.sublist(1).join(' ')
        : 'Vance';
    _usernameController.text = 'elena_daily';
    _emailController.text = user?.email ?? 'elena.v@example.com';

    // 2. Try to fetch existing Firestore data to overwrite defaults
    try {
      final stats = await _firestoreService.getUserStats(uid);
      if (stats != null && mounted) {
        if (stats.firstName != null)
          _firstNameController.text = stats.firstName!;
        if (stats.lastName != null) _lastNameController.text = stats.lastName!;
        if (stats.username != null) _usernameController.text = stats.username!;
        if (stats.email != null) _emailController.text = stats.email!;

        setState(() {
          _userStats = stats;
        });
      }
    } catch (e) {
      print('Error loading user stats: $e');
    }

    // 3. Stream for real-time updates (like photo URL)
    _firestoreService.streamUserStats(uid).listen((stats) {
      if (mounted) {
        setState(() {
          _userStats = stats;
        });
      }
    });
  }

  Future<void> _saveChanges() async {
    final uid = _authService.currentUserId;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      await _firestoreService.updateUserProfile(
        uid: uid,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Changes saved successfully'),
            backgroundColor: AppTheme.getPrimary(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndUploadProfilePicture() async {
    final uid = _authService.currentUserId;
    if (uid == null) return;

    final image = await _storageService.pickImage();
    if (image == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading profile picture...')),
    );

    final downloadUrl = await _storageService.uploadProfilePicture(uid, image);

    if (downloadUrl != null) {
      await _firestoreService.updateUserPhoto(uid, downloadUrl);

      if (mounted) {
        setState(() {
          // Update local state to reflect change immediately
          _userStats = _userStats?.copyWith(photoUrl: downloadUrl);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload profile picture')),
        );
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete Account',
          style: TextStyle(
            color: AppTheme.getTextColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete your account and all data. This action cannot be undone.',
          style: TextStyle(color: AppTheme.getMutedColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getMutedColor(context)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // In production: Delete from Firebase, then sign out
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion requested')),
              );
              _logout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.getCardColor(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.getBorderColor(context),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: AppTheme.getMutedColor(context),
                      ),
                    ),
                  ),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextColor(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 40), // Balance the back button
                ],
              ),
              const SizedBox(height: 40),

              // Profile Picture
              Stack(
                children: [
                  Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.sageGreenDark,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.sageGreenDark.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _userStats?.photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _userStats!.photoUrl!,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              placeholder: (ctx, url) => Container(
                                color: AppTheme.sageGreen,
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppTheme.sageGreenDark,
                                ),
                              ),
                              errorWidget: (ctx, err, stack) => Container(
                                color: AppTheme.sageGreen,
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppTheme.sageGreenDark,
                                ),
                              ),
                            )
                          : Container(
                              color: AppTheme.sageGreen,
                              child: Icon(
                                Icons.person,
                                size: 60,
                                color: AppTheme.sageGreenDark,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAndUploadProfilePicture,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.getPrimary(context),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'PERSONAL DETAILS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: AppTheme.mutedText,
                ),
              ),
              const SizedBox(height: 40),

              // Form Fields
              Column(
                children: [
                  _buildTextField('First Name', _firstNameController),
                  const SizedBox(height: 16),
                  _buildTextField('Last Name', _lastNameController),
                  const SizedBox(height: 16),
                  _buildTextField('Username', _usernameController, prefix: '@'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Email',
                    _emailController,
                    isEmail: true,
                    // Check if provider is password, otherwise disable editing
                    isReadOnly:
                        _authService.currentUser?.providerData.any(
                          (p) => p.providerId == 'password',
                        ) ==
                        false,
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.getPrimary(context),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 5,
                    shadowColor: AppTheme.getPrimary(
                      context,
                    ).withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    side: BorderSide(color: AppTheme.getBorderColor(context)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, size: 18, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Delete Account Button (Moved from Settings)
              const SizedBox(height: 16),
              TextButton(
                onPressed: _showDeleteConfirmation,
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    color: AppTheme.getMutedColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 40),
              Text(
                'DAILY PULSE v1.0',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppTheme.getMutedColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isEmail = false,
    String? prefix,
    bool isReadOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReadOnly
            ? AppTheme.getCardColor(context).withValues(alpha: 0.5)
            : AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isReadOnly
              ? Colors.transparent
              : AppTheme.getBorderColor(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isReadOnly
                  ? AppTheme.mutedText.withValues(alpha: 0.5)
                  : AppTheme.mutedText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (prefix != null)
                Text(
                  prefix,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.getMutedColor(context),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  readOnly: isReadOnly,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isReadOnly
                        ? AppTheme.getTextColor(context).withValues(alpha: 0.5)
                        : AppTheme.getTextColor(context),
                  ),
                  keyboardType: isEmail
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
