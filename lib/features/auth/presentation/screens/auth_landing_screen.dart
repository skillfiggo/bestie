import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthLandingScreen extends ConsumerWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We remove the listener here because it triggers on EVERY AsyncData,
    // including after sendOtp() which we DON'T want to navigate on.
    // Navigation is now handled locally in screens or by session stream.

    ref.listen<AsyncValue<void>>(
      authControllerProvider,
      (previous, next) {
        if (next is AsyncError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error.toString().replaceAll('Exception:', '').trim()),
              backgroundColor: AppColors.error,
            ),
          );
        } else if (next is AsyncData) {
           // We can check if navigation is needed here, 
           // but since landing is simple, we check if user is now logged in.
           final user = Supabase.instance.client.auth.currentUser;
           if (user != null) {
              // Sign in successful
              // We'll let the session stream or the local check below handle navigation
              // but adding a small delay or ensuring we navigate only once is good.
           }
        }
      },
    );

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AsyncLoading;

    return Scaffold(
      backgroundColor: AppColors.primary, 
      body: Stack(
        children: [
          // Background Decor (Abstract shapes)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // 1. Top Section: Mascots & Logo (Flex 4)
                  Expanded(
                    flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 160, 
                          fit: BoxFit.contain,
                        ),
                      ),
                  ),

                  // 2. Middle Section: Action Buttons (Flex 4)
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _ActionButton(
                                text: 'Google',
                                icon: Icons.g_mobiledata_rounded,
                                color: Colors.white,
                                textColor: Colors.black,
                                onPressed: isLoading ? () {} : () async {
                                  await ref.read(authControllerProvider.notifier).signInWithGoogle();
                                  if (context.mounted) {
                                    final authState = ref.read(authControllerProvider);
                                    if (authState is AsyncData) {
                                      final authRepo = ref.read(authRepositoryProvider);
                                      final user = authRepo.getCurrentUser();
                                      if (user != null) {
                                        final profile = await authRepo.getProfile(user.id);
                                        if (context.mounted) {
                                          if (profile == null || 
                                              profile['status'] == 'pending_profile' || 
                                              profile['gender'] == null || 
                                              profile['gender'] == '') {
                                            // New user or incomplete profile, go to onboarding/signup forms
                                            Navigator.pushNamedAndRemoveUntil(
                                              context, 
                                              AppRouter.authForms, 
                                              (route) => false,
                                              arguments: 1, // Go to signup tab
                                            );
                                          } else {
                                            // Existing user with complete profile
                                            Navigator.pushNamedAndRemoveUntil(
                                              context, 
                                              AppRouter.mainShell, 
                                              (route) => false
                                            );
                                          }
                                        }
                                      }
                                    }
                                  }
                                },
                              ),
                              if (isLoading)
                                const Positioned.fill(
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: -10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Recommend',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ActionButton(
                            text: 'Email',
                            icon: Icons.mail_rounded,
                            color: AppColors.primaryDark,
                            textColor: Colors.white,
                            onPressed: () {
                              Navigator.pushNamed(
                                context, 
                                AppRouter.authForms,
                                arguments: 1, // Show signup tab by default
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Social login is faster and safer',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Footer Section: Terms (Flex 1)
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            children: const [
                              TextSpan(text: 'By signing up, you are agreeing to our\n'),
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' & '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Support Headphone Icon
          Positioned(
            top: 50,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.headphones_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28), // Fully rounded Pill shape
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
             Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white, // Icon bg
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: Colors.black),
            ), // Icon styling could be adjusted to match image perfectly
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 28), // Balance the icon
          ],
        ),
      ),
    );
  }
}


