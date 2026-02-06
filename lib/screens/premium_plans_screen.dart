import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PremiumPlansScreen extends StatefulWidget {
  const PremiumPlansScreen({super.key});

  @override
  State<PremiumPlansScreen> createState() => _PremiumPlansScreenState();
}

class _PremiumPlansScreenState extends State<PremiumPlansScreen> {
  int _selectedPlanIndex = 1; // Default to Yearly (usually promoted)

  final List<Map<String, dynamic>> _plans = [
    {
      'name': 'Monthly',
      'price': '\$9.99',
      'period': '/ month',
      'savings': null,
      'description': 'Billed monthly. Cancel anytime.',
    },
    {
      'name': 'Yearly',
      'price': '\$79.99',
      'period': '/ year',
      'savings': 'Save 33%',
      'description': 'Billed annually (\$6.66/month).',
      'isPopular': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Image/Gradient
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.getBackground(context),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.getPrimary(context).withValues(alpha: 0.2),
                      AppTheme.getBackground(context),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 64,
                        color: AppTheme.sageGreenDark,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unlock Full Access',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.getTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.getTextColor(context),
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Benefits
                  _buildBenefitItem(
                    context,
                    Icons.all_inclusive_rounded,
                    'Unlimited Access',
                    'Unlock the entire library of many meditations.',
                  ),
                  _buildBenefitItem(
                    context,
                    Icons.offline_pin_rounded,
                    'Offline Mode',
                    'Download sessions and listen anywhere, anytime.',
                  ),
                  _buildBenefitItem(
                    context,
                    Icons.block_rounded,
                    'Ad-Free Experience',
                    'Focus on your practice with zero interruptions.',
                  ),

                  const SizedBox(height: 40),

                  // Plans
                  Text(
                    'Choose Your Plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 20),

                  ...List.generate(_plans.length, (index) {
                    final plan = _plans[index];
                    final isSelected = _selectedPlanIndex == index;
                    final isPopular = plan['isPopular'] == true;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedPlanIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.getCardColor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.getPrimary(context)
                                : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.getPrimary(
                                      context,
                                    ).withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  // Radio Circle
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppTheme.getPrimary(context)
                                            : AppTheme.getMutedColor(context),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppTheme.getPrimary(
                                                  context,
                                                ),
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              plan['name'],
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.getTextColor(
                                                  context,
                                                ),
                                              ),
                                            ),
                                            if (plan['savings'] != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      AppTheme.getOrangeColor(
                                                        context,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  plan['savings'],
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          plan['description'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.getMutedColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        plan['price'],
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.getTextColor(context),
                                        ),
                                      ),
                                      Text(
                                        plan['period'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.getMutedColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isPopular)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.getPrimary(context),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(14),
                                      bottomLeft: Radius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'Best Value',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Subscribe Button
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment flow coming soon!'),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.getPrimary(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.getPrimary(
                              context,
                            ).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Start 7-Day Free Trial',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Recurring billing. Cancel anytime.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.getMutedColor(context),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.getPrimary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.getPrimary(context), size: 24),
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
                    fontWeight: FontWeight.bold,
                    color: AppTheme.getTextColor(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.getMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
