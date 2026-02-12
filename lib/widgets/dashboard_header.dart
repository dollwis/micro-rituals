import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/firestore_user.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Dashboard header with greeting, date, and streak
class DashboardHeader extends StatelessWidget {
  final String dateString;
  final FirestoreUser? userStats;
  final User? currentUser;

  const DashboardHeader({
    super.key,
    required this.dateString,
    required this.userStats,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    // Get current time for greeting
    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 4 && hour < 12) {
      greeting = 'Good Morning';
    } else if (hour >= 12 && hour < 18) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    // Get user first name
    String userName = 'Friend';
    if (userStats?.firstName != null && userStats!.firstName!.isNotEmpty) {
      userName = userStats!.firstName!;
    } else if (userStats?.displayName != null &&
        userStats!.displayName.isNotEmpty) {
      userName = userStats!.displayName.split(' ').first;
    } else if (currentUser?.displayName != null) {
      userName = currentUser!.displayName!.split(' ').first;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        24, // Increased top padding for notch safety
        24,
        12,
      ), // Reduced top/bottom padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateString.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppTheme.getMutedColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$greeting, $userName',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.getTextColor(context),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
