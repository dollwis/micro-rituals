import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../screens/chat_screen.dart';

class AdminFeedbackList extends StatefulWidget {
  const AdminFeedbackList({super.key});

  @override
  State<AdminFeedbackList> createState() => _AdminFeedbackListState();
}

class _AdminFeedbackListState extends State<AdminFeedbackList> {
  final _firestoreService = FirestoreService();

  void _openChat(Map<String, dynamic> ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          ticketId: ticket['id'],
          title: ticket['title'] ?? 'No Title',
          isAdmin: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.streamAllTickets(),
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
                  size: 48,
                  color: AppTheme.getMutedColor(context).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No tickets yet.',
                  style: TextStyle(color: AppTheme.getMutedColor(context)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            final hasUnread = ticket['has_unread_admin'] as bool? ?? false;
            final title = ticket['title'] as String? ?? 'No Title';
            final lastMessage = ticket['last_message'] as String? ?? '';
            final name = ticket['user_name'] as String? ?? 'Unknown User';
            final timestamp = (ticket['last_updated'] as Timestamp?)?.toDate();

            return GestureDetector(
              onTap: () => _openChat(ticket),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasUnread
                      ? AppTheme.getCardColor(context).withValues(alpha: 0.6)
                      : AppTheme.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasUnread
                        ? AppTheme.getPrimary(context).withValues(alpha: 0.5)
                        : AppTheme.getBorderColor(
                            context,
                          ).withValues(alpha: 0.5),
                    width: hasUnread ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.getPrimary(
                          context,
                        ).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: AppTheme.getPrimary(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.getTextColor(context),
                                  fontSize: 15,
                                ),
                              ),
                              if (timestamp != null)
                                Text(
                                  _formatDate(timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.getMutedColor(context),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: hasUnread
                                  ? AppTheme.getTextColor(context)
                                  : AppTheme.getMutedColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.getPrimary(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
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
