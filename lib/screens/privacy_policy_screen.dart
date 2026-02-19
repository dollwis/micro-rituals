import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.getTextColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            color: AppTheme.getTextColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              '1. Terms of Service',
              'Last Updated: 18.02.2026\n\nWelcome to Zen Vault. By using our application, you agree to the following terms. Please read them carefully.',
            ),
            _buildSection(
              context,
              '1. The Service (Daily Rituals)',
              'The App provides three 10-minute meditation "sessions" per day, available within specific time windows. These rituals are designed to help you build a consistent mindfulness habit.',
            ),
            _buildSection(
              context,
              '2. Intellectual Property (The Music)',
              'Original Content: All musical tracks, audio recordings, and soundscapes are the exclusive property of creator of the App.\n\nLicense: We grant you a personal, non-exclusive license to stream the music for personal, non-commercial use within the App.\n\nRestrictions: You may not copy, redistribute, remix, or use the music outside of the App. Premium users may download tracks for offline use only within the App’s interface.',
            ),
            _buildSection(
              context,
              '3. Subscription & Content Tiers',
              'Free Tier: Access to basic tracks. Requires an internet connection and includes occasional advertisements (every 60 minutes of listening of content).\n\nAd-Supported: Certain tracks may be unlocked by choosing to view a reward advertisement.\n\nAd-Free Package: A one-time or recurring payment that removes all advertisements from the App.\n\nPremium Package: Includes all Ad-Free benefits, access to an exclusive "Premium" music library, and the ability to listen offline.',
            ),
            _buildSection(
              context,
              '4. Internet & Data Usage',
              'The Free and Ad-Free tiers require an active internet connection to stream music. You are responsible for any data charges incurred while using the App.',
            ),
            _buildSection(
              context,
              '5. User Statistics & Streaks',
              'The App tracks your activity history, minutes listened, and daily streaks to provide a personalized experience. While we strive for 100% accuracy, we are not liable for data loss due to technical errors or device changes.',
            ),
            _buildSection(
              context,
              '2. Privacy Policy',
              'Last Updated: 18.02.2026\n\nYour privacy is important to us. This policy explains how we handle your data to provide the best meditation experience.',
            ),
            _buildSection(
              context,
              '1. Data Controller',
              'Bartłomiej Dziedzic Contact: zenvaultcontact@gmail.com',
            ),
            _buildSection(
              context,
              '2. Information We Collect',
              'Activity Data: We collect your "minutes listened," session history, and "streaks" to visualize your progress in the "Stats" section.\n\nApp Preferences: This includes your individual notification settings for the three daily sessions and your chosen visual themes.\n\nDevice Information: We may collect basic technical data (OS version, device model) to ensure app stability.',
            ),
            _buildSection(
              context,
              '3. Advertising & Third Parties',
              'Ads: To keep the App free, we show advertisements. Third-party ad networks may use cookies or device identifiers to show relevant ads to you.\n\nAd-Free/Premium: If you purchase a paid tier, ad-tracking for those purposes will be disabled.',
            ),
            _buildSection(
              context,
              '4. Notifications',
              'The App allows you to set three individual reminders for your sessions. These are processed locally or via standard push notification services. You can opt-out at any time in your device settings.',
            ),
            _buildSection(
              context,
              '5. Offline Mode (Premium Only)',
              'When using the Offline Mode, encrypted music files are temporarily stored on your device. These files are not accessible by other apps and are deleted if the App is uninstalled or the subscription expires.',
            ),
            _buildSection(
              context,
              '6. Your Rights',
              'Under GDPR and other privacy laws, you have the right to access, correct, or delete your data. To request data deletion, please contact us at the email provided above.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.getMutedColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
