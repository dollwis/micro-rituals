import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedPlan = 'premium'; // 'adfree' or 'premium'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppTheme.getTextColor(context)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildHeroSection(context),
                    const SizedBox(height: 40),
                    _buildPlanSelection(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  // _buildBackgroundBlobs is removed

  Widget _buildHeroSection(BuildContext context) {
    return Column(
      children: [
        // Icon with verify badge feel
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.getSageColor(context).withValues(alpha: 0.1),
          ),
          child: Center(
            child: Icon(
              Icons.verified,
              size: 40,
              color: AppTheme.getPrimary(context),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Find Your Flow State',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppTheme.getTextColor(context),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Select the plan that best supports your journey to deeper meditation and lasting calm.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppTheme.getMutedColor(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSelection(BuildContext context) {
    return Column(
      children: [
        // Ad-Free Plan
        _buildPlanCard(
          context: context,
          id: 'adfree',
          title: 'Ad-Free',
          subtitle: 'Focus without interruptions',
          price: '\$4.99',
          icon: Icons.block,
          isSelected: _selectedPlan == 'adfree',
        ),
        const SizedBox(height: 16),

        // Premium Plan (Best Value)
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildPlanCard(
              context: context,
              id: 'premium',
              title: 'Premium',
              subtitle: 'Unlock listener statistics & offline',
              price: '\$9.99',
              icon: Icons.diamond_outlined,
              isSelected: _selectedPlan == 'premium',
              isPremium: true,
              features: [
                'Unlimited Access & Offline Mode',
                'Advanced Progress Stats',
                'Priority Support',
              ],
            ),
            // Best Value Badge
            Positioned(
              top: -10,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.getPrimary(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'BEST VALUE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required BuildContext context,
    required String id,
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
    required bool isSelected,
    bool isPremium = false,
    List<String>? features,
  }) {
    final primary = AppTheme.getPrimary(context);

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.getCardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : AppTheme.getBorderColor(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary.withValues(alpha: 0.1)
                        : AppTheme.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? primary
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
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.getTextColor(context),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.getMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextColor(context),
                  ),
                ),
              ],
            ),
            if (features != null && isSelected) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: AppTheme.getBorderColor(context)),
              const SizedBox(height: 16),
              ...features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check, size: 16, color: primary),
                      const SizedBox(width: 12),
                      Text(
                        f,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.getMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context).withValues(alpha: 0.8),
        border: Border(
          top: BorderSide(color: AppTheme.getBorderColor(context)),
        ),
      ),
      child: Column(
        children: [
          // CTA Button
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Subscribed to $_selectedPlan plan!'),
                  backgroundColor: AppTheme.getPrimary(context),
                ),
              );
              // In production: Process payment, then ContentAccessService.unlock...
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.getPrimary(context),
                    AppTheme.getPrimary(context).withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.getPrimary(context).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Start 7-Day Free Trial',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Footer Links
          Text(
            'Recurring billing. Cancel anytime in Settings.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.getMutedColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Terms of Service',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.getTextColor(context),
                  decoration: TextDecoration.underline,
                ),
              ),
              Text(
                ' & ',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.getMutedColor(context),
                ),
              ),
              Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.getTextColor(context),
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
