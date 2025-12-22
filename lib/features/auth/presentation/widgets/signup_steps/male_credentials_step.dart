import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_text_field.dart';

class MaleCredentialsStep extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final Function() onSignup;
  final bool isLoading;

  const MaleCredentialsStep({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onSignup,
    this.isLoading = false,
  });

  @override
  State<MaleCredentialsStep> createState() => _MaleCredentialsStepState();
}

class _MaleCredentialsStepState extends State<MaleCredentialsStep> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Text(
              'Create Account',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
             const SizedBox(height: 16),
             const Text(
              'Secure your account with an email and password.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            AuthTextField(
              label: 'Email',
              hint: 'Enter your email',
              controller: widget.emailController,
              keyboardType: TextInputType.emailAddress,
               validator: (v) => !v!.contains('@') ? 'Valid email required' : null,
            ),
            const SizedBox(height: 20),

            AuthTextField(
              label: 'Password',
              hint: 'Create a password',
              controller: widget.passwordController,
              obscureText: true,
              validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: widget.isLoading
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          widget.onSignup();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: widget.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Complete Sign Up',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
