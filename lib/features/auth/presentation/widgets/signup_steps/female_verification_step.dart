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
          const SizedBox(height: 32),
          
          // Instructions Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photo Guidelines:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInstructionRow(Icons.face_retouching_natural_rounded, 'Your face must be clearly visible'),
                _buildInstructionRow(Icons.light_mode_rounded, 'Ensure the room is well-lit (no dark photos)'),
                _buildInstructionRow(Icons.person_off_rounded, 'No photos of children or underage individuals'),
                _buildInstructionRow(Icons.group_off_rounded, 'Upload a solo photo (no group shots)'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
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
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Uploading...',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ],
                    )
                  : const Text(
                      'Verify & Continue',
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
