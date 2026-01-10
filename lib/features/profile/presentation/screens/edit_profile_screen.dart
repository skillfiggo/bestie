import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/profile/data/repositories/profile_repository.dart';
import 'package:bestie/features/profile/data/providers/profile_providers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final ProfileModel initialProfile;

  const EditProfileScreen({super.key, required this.initialProfile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _occupationController;
  late TextEditingController _locationController;
  late TextEditingController _ageController;
  String _selectedGender = 'other';
  String _selectedLookingFor = 'Friendship';
  
  final List<String> _lookingForOptions = [
    'Friendship',
    'Marriage',
    'Serious Relationship',
    'Fun',
    'Networking',
  ];
  
  File? _newAvatarImage;
  File? _newCoverImage;
  File? _newVerificationImage;
  
  // Gallery State
  List<String> _currentGalleryUrls = [];
  final List<File> _newGalleryImages = [];
  
  bool _isLoading = false;

  bool get _canEditGender {
    // If gender is set to something other than empty/other, lock it.
    final g = widget.initialProfile.gender.toLowerCase();
    return g.isEmpty || g == 'other';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile.name);
    _bioController = TextEditingController(text: widget.initialProfile.bio);
    _occupationController = TextEditingController(text: widget.initialProfile.occupation);
    _locationController = TextEditingController(text: widget.initialProfile.locationName);
    _ageController = TextEditingController(text: widget.initialProfile.age.toString());
    _selectedGender = widget.initialProfile.gender.isNotEmpty ? widget.initialProfile.gender : 'other';
    _selectedLookingFor = widget.initialProfile.lookingFor.isNotEmpty ? widget.initialProfile.lookingFor : 'Friendship';
    _currentGalleryUrls = List.from(widget.initialProfile.galleryUrls);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _occupationController.dispose();
    _locationController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isCover) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        if (isCover) {
          _newCoverImage = File(pickedFile.path);
        } else {
          _newAvatarImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _pickGalleryImage() async {
    if (_currentGalleryUrls.length + _newGalleryImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only upload up to 5 photos.')),
      );
      return;
    }
    
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _newGalleryImages.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _pickVerificationPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _newVerificationImage = File(pickedFile.path);
      });
    }
  }

  void _removeGalleryImage({int? newImageIndex, int? existingUrlIndex}) {
    setState(() {
      if (newImageIndex != null) {
        _newGalleryImages.removeAt(newImageIndex);
      } else if (existingUrlIndex != null) {
        _currentGalleryUrls.removeAt(existingUrlIndex);
      }
    });
  }

  Future<void> _updateLocationFromDevice() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium);
      
      // We could also update lat/long in the profile if we wanted, but for now just the text
      // Ideally we should update lat/long in _saveProfile too if we fetched it here.
      // But let's stick to the text for now as that's what shows "Earth".
      
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final city = place.locality ?? place.subAdministrativeArea ?? '';
        final country = place.country ?? ''; // e.g. United States
        final countryCode = place.isoCountryCode ?? '';

        String locationName = '';
        if (city.isNotEmpty && countryCode.isNotEmpty) {
          locationName = '$city, $countryCode';
        } else if (city.isNotEmpty) {
          locationName = city;
        } else if (country.isNotEmpty) {
          locationName = country;
        }
        
        if (locationName.isNotEmpty) {
          _locationController.text = locationName;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final repository = ref.read(profileRepositoryProvider);

    try {
      String? avatarUrl = widget.initialProfile.avatarUrl;
      String? coverUrl = widget.initialProfile.coverPhotoUrl;

      // Upload images if changed
      if (_newAvatarImage != null) {
         avatarUrl = await repository.uploadProfileImage(widget.initialProfile.id, _newAvatarImage!, isCover: false);
      }
      
      if (_newCoverImage != null) {
         coverUrl = await repository.uploadProfileImage(widget.initialProfile.id, _newCoverImage!, isCover: true);
      }

      // Upload new gallery images
      List<String> finalGalleryUrls = List.from(_currentGalleryUrls);
      for (var file in _newGalleryImages) {
        final url = await repository.uploadGalleryImage(widget.initialProfile.id, file);
        finalGalleryUrls.add(url);
      }

      // Update Profile Data
      final Map<String, dynamic> updates = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'occupation': _occupationController.text.trim(),
        'location': _locationController.text.trim(),
        'gender': _selectedGender,
        'looking_for': _selectedLookingFor,
        'age': int.tryParse(_ageController.text) ?? widget.initialProfile.age,
        'gallery_urls': finalGalleryUrls,
        'avatar_url': avatarUrl,
        'cover_photo_url': coverUrl,
      };

      if (_newVerificationImage != null) {
        final verificationUrl = await repository.uploadProfileImage(
          widget.initialProfile.id, 
          _newVerificationImage!, 
          isCover: false // Reusing same logic but we could have uploadVerificationImage
        );
        updates['verification_photo_url'] = verificationUrl;
        updates['status'] = 'pending_verification'; // Reset status to pending
        updates['is_verified'] = false;
      }

      await repository.updateProfile(widget.initialProfile.id, updates);

      if (mounted) {
        ref.invalidate(currentUserProfileProvider); // Refresh profile
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Image Section (Cover + Avatar)
            SizedBox(
              height: 240,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                   // Cover Photo
                  GestureDetector(
                    onTap: () => _pickImage(true),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        image: (_newCoverImage != null)
                             ? DecorationImage(image: FileImage(_newCoverImage!), fit: BoxFit.cover)
                             : (widget.initialProfile.coverPhotoUrl.isNotEmpty)
                                 ? DecorationImage(image: NetworkImage(widget.initialProfile.coverPhotoUrl), fit: BoxFit.cover)
                                 : null,
                      ),
                      child: Stack(
                        children: [
                           Container(color: Colors.black26),
                           const Center(child: Icon(Icons.camera_alt, color: Colors.white70, size: 40)),
                        ],
                      ),
                    ),
                  ),

                  // Avatar
                  Positioned(
                    bottom: 0,
                    left: 20,
                    child: GestureDetector(
                      onTap: () => _pickImage(false),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: (_newAvatarImage != null)
                                  ? FileImage(_newAvatarImage!) as ImageProvider
                                  : (widget.initialProfile.avatarUrl.isNotEmpty) 
                                      ? NetworkImage(widget.initialProfile.avatarUrl)
                                      : null,
                              child: (_newAvatarImage == null && widget.initialProfile.avatarUrl.isEmpty)
                                  ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),

            // Form Fields
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildTextField('Name', _nameController, maxLength: 20),
                  const SizedBox(height: 16),
                  _buildTextField('Bio', _bioController, maxLines: 3, maxLength: 150),
                  const SizedBox(height: 16),
                  _buildTextField('Occupation', _occupationController, maxLength: 30),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Location', 
                    _locationController, 
                    maxLength: 30,
                    suffixWidget: IconButton(
                      icon: const Icon(Icons.my_location, color: AppColors.primary),
                      onPressed: _updateLocationFromDevice,
                      tooltip: 'Use my current location',
                    ),
                  ),
                  const SizedBox(height: 16),
                   Row(
                    children: [
                      Expanded(
                        child: _buildTextField('Age', _ageController, keyboardType: TextInputType.number, maxLength: 3),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gender', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                                color: _canEditGender ? null : Colors.grey.shade100,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: ['male', 'female', 'other'].contains(_selectedGender.toLowerCase()) 
                                      ? _selectedGender.toLowerCase() 
                                      : 'other',
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'male', child: Text('Male')),
                                    DropdownMenuItem(value: 'female', child: Text('Female')),
                                    DropdownMenuItem(value: 'other', child: Text('Other')),
                                  ],
                                  onChanged: _canEditGender ? (val) {
                                    if (val != null) setState(() => _selectedGender = val);
                                  } : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Looking For Dropdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Looking For', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                       const SizedBox(height: 4),
                       Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _lookingForOptions.contains(_selectedLookingFor) ? _selectedLookingFor : _lookingForOptions.first,
                            isExpanded: true,
                            items: _lookingForOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                               if (newValue != null) setState(() => _selectedLookingFor = newValue);
                            },
                          ),
                        ),
                       ),
                    ],
                  ),

                  // Verification Section for Females
                  if (_selectedGender.toLowerCase() == 'female' && !widget.initialProfile.isVerified) ...[
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Photo Verification',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (widget.initialProfile.status == 'rejected')
                              const Icon(Icons.error_outline, color: AppColors.error, size: 14),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickVerificationPhoto,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _newVerificationImage != null 
                                    ? AppColors.primary 
                                    : (widget.initialProfile.status == 'rejected' ? AppColors.error : Colors.grey.shade300),
                                width: 2,
                              ),
                            ),
                            child: _newVerificationImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.file(_newVerificationImage!, fit: BoxFit.cover),
                                  )
                                : widget.initialProfile.verificationPhotoUrl.isNotEmpty && widget.initialProfile.status != 'rejected'
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(widget.initialProfile.verificationPhotoUrl, fit: BoxFit.cover),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.camera_front_rounded,
                                            size: 40,
                                            color: widget.initialProfile.status == 'rejected' ? AppColors.error : Colors.grey,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            widget.initialProfile.status == 'rejected'
                                                ? 'Tap to Retake Photo'
                                                : 'Tap to Take Verification Photo',
                                            style: TextStyle(
                                              color: widget.initialProfile.status == 'rejected' ? AppColors.error : Colors.grey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your face must be clearly visible. Only admins can see this photo.',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                  
                  // Gallery Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        'Gallery (${_currentGalleryUrls.length + _newGalleryImages.length}/5)', 
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)
                       ),
                       const SizedBox(height: 8),
                       GridView.builder(
                         shrinkWrap: true,
                         physics: const NeverScrollableScrollPhysics(),
                         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                           crossAxisCount: 3,
                           crossAxisSpacing: 8,
                           mainAxisSpacing: 8,
                           childAspectRatio: 1,
                         ),
                         itemCount: _currentGalleryUrls.length + _newGalleryImages.length + 1,
                         itemBuilder: (context, index) {
                           // Add Button
                           if (index == _currentGalleryUrls.length + _newGalleryImages.length) {
                             if (index >= 5) return const SizedBox.shrink();
                             return GestureDetector(
                               onTap: _pickGalleryImage,
                               child: Container(
                                 decoration: BoxDecoration(
                                   color: Colors.grey.shade100,
                                   borderRadius: BorderRadius.circular(12),
                                   border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                                 ),
                                 child: const Icon(Icons.add_photo_alternate_rounded, color: Colors.grey),
                               ),
                             );
                           }

                           // Existing URLs
                           if (index < _currentGalleryUrls.length) {
                             return Stack(
                               children: [
                                 ClipRRect(
                                   borderRadius: BorderRadius.circular(12),
                                   child: Image.network(
                                     _currentGalleryUrls[index],
                                     fit: BoxFit.cover,
                                     width: double.infinity,
                                     height: double.infinity,
                                   ),
                                 ),
                                 Positioned(
                                   top: 4,
                                   right: 4,
                                   child: GestureDetector(
                                     onTap: () => _removeGalleryImage(existingUrlIndex: index),
                                     child: Container(
                                       padding: const EdgeInsets.all(4),
                                       decoration: const BoxDecoration(
                                         color: Colors.black54,
                                         shape: BoxShape.circle,
                                       ),
                                       child: const Icon(Icons.close, size: 14, color: Colors.white),
                                     ),
                                   ),
                                 ),
                               ],
                             );
                           }

                           // New Images
                           final newImageIndex = index - _currentGalleryUrls.length;
                           return Stack(
                               children: [
                                 ClipRRect(
                                   borderRadius: BorderRadius.circular(12),
                                   child: Image.file(
                                     _newGalleryImages[newImageIndex],
                                     fit: BoxFit.cover,
                                     width: double.infinity,
                                     height: double.infinity,
                                   ),
                                 ),
                                 Positioned(
                                   top: 4,
                                   right: 4,
                                   child: GestureDetector(
                                     onTap: () => _removeGalleryImage(newImageIndex: newImageIndex),
                                     child: Container(
                                       padding: const EdgeInsets.all(4),
                                       decoration: const BoxDecoration(
                                         color: Colors.black54,
                                         shape: BoxShape.circle,
                                       ),
                                       child: const Icon(Icons.close, size: 14, color: Colors.white),
                                     ),
                                   ),
                                 ),
                               ],
                             );
                         },
                       ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType, int? maxLength, Widget? suffixWidget}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: suffixWidget,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
