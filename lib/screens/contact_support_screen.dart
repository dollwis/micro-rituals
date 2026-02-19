import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/firestore_user.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  FirestoreUser? _userStats;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  void _loadUserStats() {
    final uid = _authService.currentUserId;
    if (uid != null) {
      _firestoreService.streamUserStats(uid).listen((stats) {
        if (mounted) setState(() => _userStats = stats);
      });
    }
  }

  void _showCreateTicketDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    // We use a ValueNotifier to handle loading state inside the dialog
    // without rebuilding the whole widget tree or needing a StatefulBuilder
    // for just this simple state.
    final ValueNotifier<bool> isSubmitting = ValueNotifier(false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text(
          'New Support Ticket',
          style: TextStyle(color: AppTheme.getTextColor(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: TextStyle(color: AppTheme.getTextColor(context)),
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              style: TextStyle(color: AppTheme.getTextColor(context)),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.getMutedColor(context)),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isSubmitting,
            builder: (context, submitting, child) {
              return ElevatedButton(
                onPressed: submitting
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final message = messageController.text.trim();

                        if (title.isEmpty || message.isEmpty) return;

                        isSubmitting.value = true;

                        try {
                          final uid = _authService.currentUserId!;
                          final name =
                              _userStats?.displayName ??
                              _authService.currentUser?.displayName ??
                              'Unknown';
                          final email =
                              _userStats?.email ??
                              _authService.currentUser?.email;

                          final ticketId = await _firestoreService.createTicket(
                            uid: uid,
                            title: title,
                            message: message,
                            userName: name,
                            userEmail: email,
                          );

                          if (context.mounted) {
                            Navigator.pop(context); // Close dialog
                            // Open chat
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  ticketId: ticketId,
                                  title: title,
                                  isAdmin: false,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        } finally {
                          // If dialog is still open (error case), stop loading
                          isSubmitting.value = false;
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.getPrimary(context),
                  foregroundColor: Colors.white,
                ),
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create'),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUserId;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Support'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Log In to Contact Support'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Support Inbox',
          style: TextStyle(
            color: AppTheme.getTextColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.getCardColor(context),
        elevation: 0,
        leading: BackButton(color: AppTheme.getTextColor(context)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTicketDialog,
        backgroundColor: AppTheme.getPrimary(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Ticket',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.streamUserTickets(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tickets = snapshot.data!;

          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: AppTheme.getMutedColor(
                      context,
                    ).withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No support tickets yet.',
                    style: TextStyle(color: AppTheme.getMutedColor(context)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "New Ticket" to contact us.',
                    style: TextStyle(
                      color: AppTheme.getMutedColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final hasUnread = ticket['has_unread_user'] as bool? ?? false;
              final title = ticket['title'] as String? ?? 'No Title';
              final lastMessage = ticket['last_message'] as String? ?? '';
              final timestamp =
                  (ticket['last_updated'] as Timestamp?)?.toDate() ??
                  DateTime.now();

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        ticketId: ticket['id'],
                        title: title,
                        isAdmin: false,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasUnread
                          ? AppTheme.getPrimary(context)
                          : AppTheme.getBorderColor(context),
                      width: hasUnread ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: hasUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: AppTheme.getTextColor(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatDate(timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread
                                  ? AppTheme.getPrimary(context)
                                  : AppTheme.getMutedColor(context),
                              fontWeight: hasUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: hasUnread
                              ? AppTheme.getTextColor(context)
                              : AppTheme.getMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
