import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_button.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_text_field.dart';

class EmailStep extends StatefulWidget {
  final TextEditingController emailController;
  final VoidCallback onNext;
  final bool isLoading;

  const EmailStep({
    super.key,
    required this.emailController,
    required this.onNext,
    required this.isLoading,
  });

  @override
  State<EmailStep> createState() => _EmailStepState();
}

class _EmailStepState extends State<EmailStep> {
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
              'What\'s your email?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll send a verification code to your inbox',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            AuthTextField(
              controller: widget.emailController,
              label: 'Email Address',
              hint: 'example@email.com',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Email is required';
                if (!value.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const Spacer(),
            AuthButton(
              text: 'Send Code',
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
