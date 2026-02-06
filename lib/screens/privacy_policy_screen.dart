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
              '1. Introduction',
              'Welcome to Daily Pulse ("we," "our," or "us"). We are committed to protecting your personal information and your right to privacy. If you have any questions or concerns about our policy, or our practices with regards to your personal information, please contact us.',
            ),
            _buildSection(
              context,
              '2. Information We Collect',
              'We collect personal information that you voluntarily provide to us when registering at the Services expressing an interest in obtaining information about us or our products and services, when participating in activities on the Services or otherwise contacting us.',
            ),
            _buildSection(
              context,
              '3. How We Use Your Information',
              'We use personal information collected via our Services for a variety of business purposes described below. We process your personal information for these purposes in reliance on our legitimate business interests, in order to enter into or perform a contract with you, with your consent, and/or for compliance with our legal obligations.',
            ),
            _buildSection(
              context,
              '4. Will Your Information Be Shared With Anyone?',
              'We only share information with your consent, to comply with laws, to provide you with services, to protect your rights, or to fulfill business obligations.',
            ),
            _buildSection(
              context,
              '5. How Long Do We Keep Your Information?',
              'We keep your information for as long as necessary to fulfill the purposes outlined in this privacy policy unless otherwise required by law.',
            ),
            _buildSection(
              context,
              '6. Contact Us',
              'If you have questions or comments about this policy, you may email us at support@dailypulse.app',
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
