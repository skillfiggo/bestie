import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_button.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_text_field.dart';

class PasswordStep extends StatefulWidget {
  final TextEditingController passwordController;
  final VoidCallback onNext;
  final bool isLoading;

  const PasswordStep({
    super.key,
    required this.passwordController,
    required this.onNext,
    required this.isLoading,
  });

  @override
  State<PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<PasswordStep> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a password',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a strong password to secure your account',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            AuthTextField(
              controller: widget.passwordController,
              label: 'Password',
              hint: 'Minimum 6 characters',
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Password is required';
                if (value.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const Spacer(),
            AuthButton(
              text: 'Continue',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onNext();
                }
              },
              isLoading: widget.isLoading,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
