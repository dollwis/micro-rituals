import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/neumorphic_button.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'The Purpose',
      slogan: 'Three Moments of Calm',
      description:
          'Small steps lead to big changes. Establish a lasting habit with dedicated 10-minute meditation windows for your morning, afternoon, and evening.',
      icon: Icons.spa_rounded,
      buttonText: 'Next',
    ),
    OnboardingPageData(
      title: 'The Music',
      slogan: 'Handcrafted Soundscapes',
      description:
          'Immerse yourself in the Zen Vault. Every track is an original composition designed to resonate with your breath and elevate your mindfulness journey.',
      icon: Icons.music_note_rounded,
      buttonText: 'Continue',
    ),
    OnboardingPageData(
      title: 'The Experience',
      slogan: 'Focus on What Matters',
      description:
          'No distractions, no clutter. Follow simple visual cues and gentle guidance to stay present and find your inner balance.',
      icon: Icons.self_improvement_rounded,
      buttonText: 'Let’s Begin',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bg = AppTheme.getBackground(context);
    final text = AppTheme.getTextColor(context);
    final primary = AppTheme.getPrimary(context);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Content
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _OnboardingPage(
                data: _pages[index],
                isDark: isDark,
                primary: primary,
                text: text,
              );
            },
          ),

          // Bottom Navigation Area
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Page Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? primary
                            : primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action Button
                NeumorphicButton(
                  onPressed: _nextPage,
                  backgroundColor: primary,
                  width: double.infinity,
                  child: Text(
                    _pages[_currentPage].buttonText,
                    style: TextStyle(
                      color: isDark ? AppTheme.backgroundDark : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_currentPage == 2)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: text.withValues(alpha: 0.6),
                        ),
                        children: [
                          const TextSpan(
                            text: 'By clicking continue you agree to our\n',
                          ),
                          TextSpan(
                            text: 'Terms and Privacy Policy',
                            style: TextStyle(
                              color: primary,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

class OnboardingPageData {
  final String title;
  final String slogan;
  final String description;
  final IconData icon;
  final String buttonText;

  OnboardingPageData({
    required this.title,
    required this.slogan,
    required this.description,
    required this.icon,
    required this.buttonText,
  });
}

class _OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;
  final bool isDark;
  final Color primary;
  final Color text;

  const _OnboardingPage({
    required this.data,
    required this.isDark,
    required this.primary,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon/Illustration Placeholder
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 80, color: primary),
          ),
          const SizedBox(height: 48),

          // Title (The Purpose, etc.)
          Text(
            data.title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: primary,
            ),
          ),
          const SizedBox(height: 16),

          // Slogan
          Text(
            data.slogan,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),

          // Description
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: text.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
