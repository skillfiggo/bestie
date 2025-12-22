import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_text_field.dart';

class FemaleProfileStep extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController dobController;
  final Function() onNext;

  const FemaleProfileStep({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.dobController,
    required this.onNext,
  });

  @override
  State<FemaleProfileStep> createState() => _FemaleProfileStepState();
}

class _FemaleProfileStepState extends State<FemaleProfileStep> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tell us about yourself',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your name and age will be shown on your profile.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            // Name
            AuthTextField(
              label: 'Full Name',
              hint: 'Enter your name',
              controller: widget.nameController,
              validator: (v) => v!.isEmpty ? 'Name required' : null,
            ),
            const SizedBox(height: 20),

            // Birthday (Read Only - opens DatePicker)
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  widget.dobController.text = "${date.year}-${date.month}-${date.day}";
                }
              },
              child: AbsorbPointer(
                child: AuthTextField(
                  label: 'Birthday',
                  hint: 'YYYY-MM-DD',
                  controller: widget.dobController,
                  validator: (v) => v!.isEmpty ? 'Birthday required' : null,
                  suffixIcon: const Icon(Icons.calendar_today_rounded),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Email & Password (for account)
            AuthTextField(
              label: 'Email',
              hint: 'Enter your email',
              controller: widget.emailController,
              validator: (v) => !v!.contains('@') ? 'Valid email required' : null,
              keyboardType: TextInputType.emailAddress,
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
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Validate Age (Must be 18+)
                    final dob = widget.dobController.text; // YYYY-MM-DD
                    if (dob.isEmpty) return; // Should be caught by validator

                    try {
                      final birthDate = DateTime.parse(dob);
                      final today = DateTime.now();
                      int age = today.year - birthDate.year;
                      if (today.month < birthDate.month ||
                          (today.month == birthDate.month && today.day < birthDate.day)) {
                        age--;
                      }

                      if (age < 18) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You must be 18+ to sign up as Female'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      
                      widget.onNext();
                    } catch (e) {
                      // Parse error?
                      widget.onNext();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Continue',
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
