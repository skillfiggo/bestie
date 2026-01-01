import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bestie/core/constants/app_colors.dart';

class FemaleVerificationStep extends ConsumerStatefulWidget {
  final Function(String photoUrl) onVerify; // Modified to pass URL
  final bool isLoading;

  const FemaleVerificationStep({
    super.key,
    required this.onVerify,
    this.isLoading = false,
  });

  @override
  ConsumerState<FemaleVerificationStep> createState() => _FemaleVerificationStepState();
}

class _FemaleVerificationStepState extends ConsumerState<FemaleVerificationStep> {
  final _picker = ImagePicker();
  File? _imageFile;

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera, // Force camera for verification
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capture photo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Add a Photo',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          // ... (text same)
          const SizedBox(height: 16),
          const Text(
            'We will analyze your photo to verify your age and ensure your face is clear.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          
          // Photo Placeholder
          GestureDetector(
            onTap: _pickAndUploadImage,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _imageFile != null ? AppColors.primary : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt_rounded, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Tap to take photo',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _imageFile != null && !widget.isLoading 
                  ? () => widget.onVerify(_imageFile!.path) 
                  : null,
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
                      'Verify & Continue',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
