import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter both email and password'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );
      if (result != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed';
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        errorMessage = "Account doesn't exist";
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password';
      } else {
        errorMessage = e.message ?? 'Unknown error';
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Login Failed'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithGoogle();
      if (result != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithFacebook() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithFacebook();
      if (result != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInAnonymously();
      if (result != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guest login failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'Welcome',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.getTextColor(context),
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please sign in to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.getMutedColor(context),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.getCardDecoration(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField(
                          'EMAIL ADDRESS',
                          'name@example.com',
                          false,
                          _emailController,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          'PASSWORD',
                          '••••••••',
                          true,
                          _passwordController,
                        ),
                        const SizedBox(height: 24),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.getPrimary(context),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shadowColor: AppTheme.getPrimary(
                                context,
                              ).withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Log In',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppTheme.getBorderColor(context),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.mutedText.withValues(alpha: 0.4),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppTheme.getBorderColor(context),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Social Buttons
                  _buildSocialButton(
                    'Sign in with Google',
                    '<svg viewBox="0 0 24 24"><path d="M12.48 10.92v3.28h7.84c-.24 1.84-.92 3.36-2.12 4.48-1.2 1.12-2.92 1.88-5.72 1.88-4.44 0-8.08-3.6-8.08-8.08s3.64-8.08 8.08-8.08c2.44 0 4.24.96 5.56 2.24l2.32-2.32C18.48 2.48 15.84 1.2 12.48 1.2 6.48 1.2 1.6 6.08 1.6 12.08s4.88 10.88 10.88 10.88c3.24 0 5.72-1.08 7.64-3.08 2-2 2.64-4.8 2.64-7.12 0-.48-.04-.96-.12-1.44h-10.16z"></path></svg>',
                    _signInWithGoogle,
                  ),
                  const SizedBox(height: 12),
                  _buildSocialButton(
                    'Sign in with Facebook',
                    '<svg viewBox="0 0 24 24"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.469h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"></path></svg>',
                    _signInWithFacebook,
                  ),
                  const SizedBox(height: 12),
                  _buildSocialButton(
                    'Sign in with Apple',
                    '<svg viewBox="0 0 24 24"><path d="M17.073 10.22c-.015-2.22 1.83-3.29 1.91-3.34-1.04-1.52-2.65-1.73-3.23-1.75-1.37-.14-2.68.8-3.38.8-.69 0-1.78-.79-2.93-.77-1.51.02-2.9.88-3.68 2.23-1.56 2.73-.4 6.78 1.13 8.98.75 1.08 1.63 2.29 2.8 2.24 1.12-.04 1.55-.73 2.91-.73 1.35 0 1.74.73 2.92.71 1.2-.02 1.97-1.1 2.71-2.18.86-1.25 1.21-2.46 1.23-2.53-.02-.01-2.37-.91-2.39-3.66zM14.773 3.65c.62-.75 1.03-1.79.92-2.82-.89.04-1.97.6-2.6 1.34-.57.66-1.07 1.73-.94 2.74.99.08 2.01-.51 2.62-1.26z"></path></svg>',
                    () {}, // Apple sign-in not implemented yet
                  ),
                  const SizedBox(height: 24),

                  // Continue as Guest
                  Center(
                    child: TextButton(
                      onPressed: _continueAsGuest,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.mutedText,
                      ),
                      child: const Text(
                        'Continue as Guest',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.mutedText.withValues(alpha: 0.6),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.sageGreen),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    String placeholder,
    bool isPassword,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText.withValues(alpha: 0.6),
              letterSpacing: 1,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.getTextColor(context),
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              color: AppTheme.getMutedColor(context).withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: AppTheme.getCardColor(context),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.getBorderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.getPrimary(context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(
    String text,
    String svgString,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.getCardColor(context),
          foregroundColor: AppTheme.getTextColor(context),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.getBorderColor(context)),
          ),
          splashFactory: NoSplash
              .splashFactory, // To emulate active:scale roughly manually or just simple press
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: SvgPicture.string(
                svgString,
                colorFilter: ColorFilter.mode(
                  AppTheme.getTextColor(context),
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
