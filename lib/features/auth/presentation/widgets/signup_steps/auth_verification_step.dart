import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_button.dart';

class AuthVerificationStep extends StatefulWidget {
  final String email;
  final Function(String) onVerify;
  final VoidCallback onResend;
  final bool isLoading;

  const AuthVerificationStep({
    super.key,
    required this.email,
    required this.onVerify,
    required this.onResend,
    required this.isLoading,
  });

  @override
  State<AuthVerificationStep> createState() => _AuthVerificationStepState();
}

class _AuthVerificationStepState extends State<AuthVerificationStep> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify Email',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit code sent to ${widget.email}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            onChanged: (value) {
              if (value.length == 6) {
                widget.onVerify(value.trim());
              }
            },
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: widget.isLoading ? null : widget.onResend,
              child: const Text(
                "Didn't receive code? Resend",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Spacer(),
          AuthButton(
            text: 'Verify',
            onPressed: () {
              if (_codeController.text.length == 6) {
                widget.onVerify(_codeController.text.trim());
              }
            },
            isLoading: widget.isLoading,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
