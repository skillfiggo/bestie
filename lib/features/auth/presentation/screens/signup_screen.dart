import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/presentation/screens/verification_screen.dart';
import 'package:bestie/app/router.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/gender_step.dart';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/female_profile_step.dart';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/female_verification_step.dart';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/male_name_step.dart';
import 'dart:io';
import 'package:bestie/features/auth/presentation/widgets/signup_steps/male_credentials_step.dart';
import 'package:bestie/features/common/data/repositories/storage_repository.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToLogin;

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


  Future<void> _handleSignup([String? verificationPhotoPath]) async {
    final age = _calculateAge(_dobController.text);
    
    // 1. Sign Up (creates user and placeholder profile)
    await ref.read(authControllerProvider.notifier).signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      userData: {
        'name': _nameController.text.trim(),
        'gender': _gender ?? 'other',
        'age': age,
        'bio': 'New to Bestie!',
        'avatar_url': '', 
        'interests': [],
        // We can't send verification photo URL yet because we aren't signed in to upload it
      },
    );

    // 2. If success and we have a photo, upload it
    if (verificationPhotoPath != null) {
       final authRepo = ref.read(authRepositoryProvider);
       final storageRepo = ref.read(storageRepositoryProvider);
       final user = authRepo.getCurrentUser();
       
       if (user != null) {
         try {
           final path = '${user.id}/verification_${DateTime.now().millisecondsSinceEpoch}.jpg';
           final url = await storageRepo.uploadFile(
             bucket: 'avatars', // Using avatars bucket for now
             path: path,
             file: File(verificationPhotoPath),
           );
           
           // 3. Update profile with URL
           await authRepo.updateProfile(user.id, {
             'verification_photo_url': url,
           });
         } catch (e) {
           print('Verification upload failed: $e');
           // Don't block signup success
         }
       }
    }
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

  Future<bool> _onWillPop() async {
     if (_pageController.hasClients && _pageController.page! > 0) {
       _previousPage();
       return false;
     }
     return true; 
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(
      authControllerProvider,
      (previous, next) {
        next.whenOrNull(
          data: (_) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VerificationScreen(email: _emailController.text.trim()),
              ),
            );
          },
              error: (error, stackTrace) {
               String message = error.toString().replaceAll('Exception:', '').trim();
               if (message.contains('rate_limit') || message.contains('429')) {
                 message = 'Please wait a minute before trying again (Security Limit).';
               } else if (message.contains('User already registered')) {
                 message = 'This email is already registered. Try logging in.';
               }
               
               ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 4),
                ),
              );
            },
        );
      },
    );

    final isLoading = ref.watch(authControllerProvider).isLoading;

    // Define pages based on state
    List<Widget> pages = [
      GenderStep(onGenderSelected: _onGenderSelected),
    ];

    if (_gender == 'female') {
      pages.addAll([
        FemaleProfileStep(
          nameController: _nameController,
          emailController: _emailController,
          passwordController: _passwordController,
          dobController: _dobController,
          onNext: _nextPage,
        ),
        FemaleVerificationStep(
          onVerify: _handleSignup,
          isLoading: isLoading,
        ),
      ]);
    } else if (_gender == 'male') {
      pages.addAll([
        MaleNameStep(
          nameController: _nameController,
          onNext: _nextPage,
        ),
         MaleCredentialsStep(
          emailController: _emailController,
          passwordController: _passwordController,
          onSignup: _handleSignup,
          isLoading: isLoading,
        ),
      ]);
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Column(
        children: [
            // Custom App Bar for back navigation within steps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                   IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () {
                      if (_pageController.hasClients && _pageController.page! > 0) {
                        _previousPage();
                      } else {
                         // Or pop
                        widget.onSwitchToLogin();
                      }
                    },
                    color: AppColors.textPrimary,
                  ),
                  const Spacer(),
                   if (_gender == null) // Show Login option only on first step
                      TextButton(
                      onPressed: widget.onSwitchToLogin,
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
