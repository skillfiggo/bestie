import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/app/router.dart';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/email_step.dart';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/auth_verification_step.dart';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/password_step.dart';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/profile_details_step.dart';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/gender_step.dart';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/female_verification_step.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final Function(String?) onSwitchToLogin;

  const SignupScreen({
    super.key,
    required this.onSwitchToLogin,
  });

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final PageController _pageController = PageController();
  
  // State
  // State flags for transitions
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _passwordSet = false;
  String? _gender;

  // Controllers
  final _nameController = TextEditingController(); // Full Name or Display Name
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dobController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  int _calculateAge(String dob) {
    if (dob.isEmpty) return 18; // Default if not provided
    try {
      // Assuming format DD/MM/YYYY or YYYY-MM-DD
      // Let's try to parse flexible formats
      DateTime? birthDate;
      if (dob.contains('/')) {
        final parts = dob.split('/');
        if (parts.length == 3) {
           // simple parse DD/MM/YYYY
           birthDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } else {
        birthDate = DateTime.tryParse(dob);
      }
      
      if (birthDate == null) return 18;
      
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month || 
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 18;
    }
  }


  Future<void> _handleSendOtp() async {
    await ref.read(authControllerProvider.notifier).startSignup(_emailController.text.trim());
  }

  void _showEmailExistsDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Exists'),
        content: Text('An account with $email already exists. Would you like to sign in instead?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSwitchToLogin(email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, // Changed to primary green to match design better
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVerify(String code) async {
    await ref.read(authControllerProvider.notifier).verifyOtp(
      email: _emailController.text.trim(),
      token: code,
    );
  }

  Future<void> _onOtpVerified() async {
    final user = ref.read(authRepositoryProvider).getCurrentUser();
    if (user != null) {
      try {
        await ref.read(authRepositoryProvider).createProfile(user.id, {
          'status': 'pending_profile',
        });
      } catch (e) {
        debugPrint('Initial profile creation failed (might already exist): $e');
      }
    }
  }

  Future<void> _handlePasswordSet() async {
    await ref.read(authControllerProvider.notifier).updatePassword(_passwordController.text);
  }

  Future<void> _handleProfileComplete([String? verificationPhotoPath]) async {
    final age = _calculateAge(_dobController.text);
    
    // Show feedback that upload is starting
    if (verificationPhotoPath != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading verification photo...'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.primary,
        ),
      );
    }
    
    await ref.read(authControllerProvider.notifier).completeProfile(
      name: _nameController.text.trim(),
      gender: _gender ?? 'other',
      age: age,
      verificationPhotoPath: verificationPhotoPath,
    );
  }

  void _onGenderSelected(String gender) {
     setState(() {
       _gender = gender;
     });
     // Wait for rebuild then move
     WidgetsBinding.instance.addPostFrameCallback((_) {
       _nextPage();
     });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(
      authControllerProvider,
      (previous, next) {
        if (next is AsyncData) {
          final currentPage = (_pageController.hasClients ? _pageController.page?.round() : 0) ?? 0;
          
          if (currentPage == 0 && !_otpSent) {
            setState(() => _otpSent = true);
            _nextPage();
          } else if (currentPage == 1 && !_otpVerified) {
            setState(() => _otpVerified = true);
            _onOtpVerified();
            _nextPage();
          } else if (currentPage == 2 && !_passwordSet) {
            setState(() => _passwordSet = true);
            _nextPage();
          } else if (currentPage >= 4) {
            // Profile completion successful
            Navigator.pushNamedAndRemoveUntil(
              context, 
              AppRouter.mainShell, 
              (route) => false
            );
          }
        } else if (next is AsyncError) {
          String message = next.error.toString().replaceAll('Exception:', '').trim();
          
          if (message == 'email_exists') {
            _showEmailExistsDialog(_emailController.text.trim());
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );

    final isLoading = ref.watch(authControllerProvider).isLoading;

    // Define pages based on state
    List<Widget> pages = [
      // 0: Email
      EmailStep(
        emailController: _emailController,
        onNext: _handleSendOtp,
        isLoading: isLoading,
      ),
      // 1: OTP
      AuthVerificationStep(
        email: _emailController.text,
        onVerify: _handleVerify,
        onResend: _handleSendOtp,
        isLoading: isLoading,
      ),
      // 2: Password
      PasswordStep(
        passwordController: _passwordController,
        onNext: _handlePasswordSet,
        isLoading: isLoading,
      ),
      // 3: Gender
      GenderStep(onGenderSelected: _onGenderSelected),
      // 4: Profile Details
      ProfileDetailsStep(
        nameController: _nameController,
        dobController: _dobController,
        onNext: () {
          if (_gender == 'female') {
            _nextPage();
          } else {
            _handleProfileComplete();
          }
        },
      ),
    ];

    if (_gender == 'female') {
      // 5: Photo Verification
      pages.add(
        FemaleVerificationStep(
          onVerify: _handleProfileComplete,
          isLoading: isLoading,
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final currentPage = (_pageController.hasClients ? _pageController.page?.round() : 0) ?? 0;
        
        // Prevent going back after password stage (step 2)
        if (currentPage > 2) {
          return; // Do nothing - user cannot go back
        }
        
        if (currentPage > 0) {
          _previousPage();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Column(
        children: [
            // Custom App Bar for back navigation within steps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  // Only show back button before and during password stage
                  if (((_pageController.hasClients ? _pageController.page?.round() : 0) ?? 0) <= 2)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () {
                        final currentPage = (_pageController.hasClients ? _pageController.page?.round() : 0) ?? 0;
                        
                        if (currentPage > 0) {
                          _previousPage();
                        } else {
                           // Or pop
                          widget.onSwitchToLogin(null);
                        }
                      },
                      color: AppColors.textPrimary,
                    ),
                  const Spacer(),
                   if (_gender == null) // Show Login option only on first step
                      TextButton(
                      onPressed: () => widget.onSwitchToLogin(null),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}
