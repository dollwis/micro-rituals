import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/firestore_user.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _messageController = TextEditingController();

  FirestoreUser? _userStats;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = _authService.currentUserId;
    if (uid != null) {
      // 1. Try to fetch fresh stats
      final stats = await _firestoreService.getUserStats(uid);
      if (stats != null && mounted) {
        setState(() => _userStats = stats);
      }

      // 2. Also stream updates
      _firestoreService.streamUserStats(uid).listen((stats) {
        if (mounted) {
          setState(() => _userStats = stats);
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendSupportEmail() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message to send.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final uid = _authService.currentUserId ?? 'unknown_uid';
    final name =
        _userStats?.displayName ??
        _authService.currentUser?.displayName ??
        'Unknown Name';
    final email =
        _userStats?.email ??
        _authService.currentUser?.email ??
        'unknown@example.com';

    final recipient = 'bartek1999dziedzic@gmail.com';
    final subject = 'Support Request: $name';
    final body =
        '''
${_messageController.text}

--------------------------------
User Details (Auto-generated):
ID: $uid
Name: $name
Email: $email
App Version: 1.0.0+1
''';

    final uri = Uri(
      scheme: 'mailto',
      path: recipient,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) {
          _messageController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Opening email client...'),
              backgroundColor: AppTheme.getSageColor(context),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open email client. Please email bartek1999dziedzic@gmail.com directly.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error launching email: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Contact Support',
          style: TextStyle(
            color: AppTheme.getTextColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: AppTheme.getTextColor(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.getPrimary(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Your Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getTextColor(context),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Name',
                    _userStats?.displayName ??
                        _authService.currentUser?.displayName ??
                        '-',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Email',
                    _userStats?.email ?? _authService.currentUser?.email ?? '-',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'How can we help you?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.getTextColor(context),
              ),
            ),
            const SizedBox(height: 12),

            // Message Field
            Container(
              decoration: BoxDecoration(
                color: AppTheme.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 8,
                style: TextStyle(color: AppTheme.getTextColor(context)),
                decoration: const InputDecoration(
                  hintText: 'Type your message here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Send Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendSupportEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.getPrimary(context),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _isLoading ? 'Opening Email Client...' : 'Send Message',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'This will open your default email app.',
                style: TextStyle(
                  color: AppTheme.getMutedColor(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isSmall = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.getMutedColor(context),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmall ? 11 : 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.getTextColor(context),
              fontFamily: isSmall ? 'Monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}
