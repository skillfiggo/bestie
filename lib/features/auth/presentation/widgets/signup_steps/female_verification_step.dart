import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';

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
  bool _isUploading = false;

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
          _isUploading = true;
        });

        // Upload to storage
        final storageRepo = ref.read(storageRepositoryProvider);
        final authRepo = ref.read(authRepositoryProvider);
        final user = authRepo.getCurrentUser();
        
        // We might not have a user ID yet if not signed up, 
        // BUT this step is usually *before* signup call in this flow?
        // Wait, SignUpScreen calls signUp *after* this step.
        // So we don't have a user ID. 
        // We can upload to a temporary path or use a timestamp-based name 
        // and let RLS allow public insert? 
        // OR: SignUpScreen should create user first?
        // Checking SignUpScreen logic: _handleSignup calls signUp.
        // So user doesn't exist yet. Auth policies allow insert for authenticated only.
        // Catch-22. 
        // Solution: SignUp flow should be:
        // 1. SignUp (create auth user)
        // 2. Profile Creation (trigger/repo)
        // 3. Upload Verification (now we have ID)
        // 
        // IF we do it before, we need a public bucket or anonymous upload. 
        // Schema policy: "Auth Upload" requires 'authenticated'.
        
        // Let's check if SignUpScreen actually signs up *before* this step? 
        // No, it collects data then calls signUp.
        
        // WORKAROUND: For now, we will just pick the file and pass the FILE path 
        // to parent, and parent uploads AFTER signup?
        // Or parent accepts File object.
        
        // Updating parent (SignUpScreen) is safer.
        // But to keep it simple and consistent with "onVerify" callback:
        // I will change onVerify to accept File? and handle upload in parent 
        // AFTER successful signup but BEFORE creating profile? 
        // No, signUp does both.
        
        // Better approach:
        // Pass the File back to SignUpScreen.
        // In _handleSignup:
        // 1. Call auth.signUp (creates user & basic profile).
        // 2. Login valid.
        // 3. Upload image using new user ID.
        // 4. Update profile with image URL.
        
        // So this widget just picks the image.
        
        setState(() => _isUploading = false);
        
        // Auto-trigger verify if needed, or just let user click button
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capture photo: $e')),
      );
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
