import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/app/router.dart';

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary, // Using primary green as background base
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
                color: Colors.white.withOpacity(0.1),
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
                color: AppColors.lime.withOpacity(0.2),
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
                          width: 160, // Reduced from 280
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
                                onPressed: () {},
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
                                text: 'Sign Up',
                                icon: Icons.flash_on_rounded,
                                color: AppColors.primaryDark,
                                textColor: Colors.white,
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context, 
                                    AppRouter.authForms,
                                    arguments: 1,
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _ActionButton(
                                text: 'Demo Login',
                                icon: Icons.developer_mode,
                                color: Colors.grey.shade200,
                                textColor: Colors.black87,
                                onPressed: () {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    AppRouter.mainShell,
                                    (route) => false,
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                          
                              // Social Icons Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _SocialCircleButton(
                                    icon: Icons.facebook,
                                    color: const Color(0xFF1877F2),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 20),
                                  _SocialCircleButton(
                                    icon: Icons.phone_rounded,
                                    color: AppColors.lime,
                                    iconColor: Colors.black,
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 20),
                                  _SocialCircleButton(
                                    icon: Icons.mail_rounded,
                                    color: Colors.black, // Matches image style
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context, 
                                        AppRouter.authForms,
                                        arguments: 1,
                                      );
                                    },
                                  ),
                                ],
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
                              color: Colors.white.withOpacity(0.7),
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
                color: Colors.black.withOpacity(0.1),
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

class _SocialCircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onPressed;

  const _SocialCircleButton({
    required this.icon,
    required this.color,
    this.iconColor = Colors.white,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }
}

class _MascotPlaceholder extends StatelessWidget {
  final Color color;
  final double size;
  final double angle;

  const _MascotPlaceholder({
    required this.color,
    required this.size,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        // Simple face for effect
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Eye(),
              const SizedBox(width: 10),
              _Eye(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Eye extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
    );
  }
}
