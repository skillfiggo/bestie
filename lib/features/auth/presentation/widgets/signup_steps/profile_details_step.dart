import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:bestie/features/auth/presentation/widgets/auth_button.dart';

class ProfileDetailsStep extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController dobController;
  final VoidCallback onNext;

  const ProfileDetailsStep({
    super.key,
    required this.nameController,
    required this.dobController,
    required this.onNext,
  });

  @override
  State<ProfileDetailsStep> createState() => _ProfileDetailsStepState();
}

class _ProfileDetailsStepState extends State<ProfileDetailsStep> {
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
              'Personal Details',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Just a few more things to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            AuthTextField(
              controller: widget.nameController,
              label: 'Nickname',
              hint: 'How should we call you?',
              validator: (v) => v!.isEmpty ? 'Nickname is required' : null,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  widget.dobController.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                }
              },
              child: AbsorbPointer(
                child: AuthTextField(
                  controller: widget.dobController,
                  label: 'Birthday',
                  hint: 'YYYY-MM-DD',
                  validator: (v) => v!.isEmpty ? 'Birthday required' : null,
                  suffixIcon: const Icon(Icons.calendar_today_rounded),
                ),
              ),
            ),
            const Spacer(),
            AuthButton(
              text: 'Continue',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onNext();
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
