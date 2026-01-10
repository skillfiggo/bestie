import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_button.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (_formKey.currentState!.validate()) {
      // 1. Verify OTP with type recovery
      await ref.read(authControllerProvider.notifier).verifyRecoveryOtp(
        email: widget.email,
        token: _otpController.text.trim(),
      );

      if (mounted) {
        final state = ref.read(authControllerProvider);
        if (!state.hasError) {
          // 2. Update password
          await ref.read(authControllerProvider.notifier).updatePassword(
            _passwordController.text,
          );

          if (mounted) {
            final updateState = ref.read(authControllerProvider);
            if (!updateState.hasError) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password reset successful! Please login with your new password.'),
                  backgroundColor: Colors.green,
                ),
              );
              // Pop back to login
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(
      authControllerProvider,
      (previous, next) {
        next.whenOrNull(
          error: (error, stackTrace) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error.toString().replaceAll('Exception:', '').trim()),
                backgroundColor: AppColors.error,
              ),
            );
          },
        );
      },
    );

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to ${widget.email} and your new password.',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              
              // OTP field
              AuthTextField(
                label: 'Verification Code',
                hint: 'Enter 6-digit code',
                controller: _otpController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter the code';
                  if (value.length < 6) return 'Code must be 6 digits';
                  return null;
                },
                enabled: !isLoading,
              ),
              const SizedBox(height: 20),
              
              // Password field
              AuthTextField(
                label: 'New Password',
                hint: 'Enter new password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a password';
                  if (value.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
                enabled: !isLoading,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              
              const SizedBox(height: 32),
              AuthButton(
                text: 'Reset Password',
                onPressed: _handleReset,
                isLoading: isLoading,
              ),
              
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: isLoading ? null : () {
                    ref.read(authControllerProvider.notifier).resetPassword(widget.email);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification code resent')),
                    );
                  },
                  child: const Text(
                    'Resend Code',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
