import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/profile/data/repositories/profile_repository.dart';

class PersonalInformationScreen extends ConsumerStatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  ConsumerState<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends ConsumerState<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _occupationController;
  late TextEditingController _locationController;
  
  String _selectedGender = 'male';
  int _selectedAge = 18;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _occupationController = TextEditingController();
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _occupationController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _loadProfileData(ProfileModel profile) {
    _nameController.text = profile.name;
    _bioController.text = profile.bio;
    _occupationController.text = profile.occupation;
    _locationController.text = profile.locationName;
    _selectedGender = profile.gender;
    _selectedAge = profile.age;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final currentProfile = await ref.read(userProfileProvider.future);
      
      if (currentProfile == null) {
        throw Exception('Profile not found');
      }

      await profileRepo.updateProfile(
        currentProfile.id,
        {
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'occupation': _occupationController.text.trim(),
          'location': _locationController.text.trim(),
          'gender': _selectedGender,
          'age': _selectedAge,
        },
      );

      // Refresh profile
      ref.invalidate(userProfileProvider);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal information updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Personal Information',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (_isEditing) {
              _showDiscardDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.primary),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          // Load data only once when profile is available
          if (_nameController.text.isEmpty) {
            _loadProfileData(profile);
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Profile Picture Section
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: profile.avatarUrl.isNotEmpty
                            ? NetworkImage(profile.avatarUrl)
                            : null,
                        child: profile.avatarUrl.isEmpty
                            ? Text(
                                profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              )
                            : null,
                      ),
                      if (profile.isVerified)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    profile.bestieId.isNotEmpty ? 'ID: ${profile.bestieId}' : 'ID: ${profile.id.substring(0, 8)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                _buildSectionHeader('Basic Information'),
                const SizedBox(height: 16),

                // Name Field
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  enabled: _isEditing,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Gender Selection
                _buildGenderSelector(),
                const SizedBox(height: 16),

                // Age Selector
                _buildAgeSelector(),
                const SizedBox(height: 16),

                // Bio Field
                _buildTextField(
                  controller: _bioController,
                  label: 'Bio',
                  icon: Icons.info_outline,
                  enabled: _isEditing,
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: 32),

                _buildSectionHeader('Professional Details'),
                const SizedBox(height: 16),

                // Occupation Field
                _buildTextField(
                  controller: _occupationController,
                  label: 'Occupation',
                  icon: Icons.work_outline,
                  enabled: _isEditing,
                ),
                const SizedBox(height: 32),

                _buildSectionHeader('Location'),
                const SizedBox(height: 16),

                // Location Field
                _buildTextField(
                  controller: _locationController,
                  label: 'City/Region',
                  icon: Icons.location_on_outlined,
                  enabled: _isEditing,
                ),

                const SizedBox(height: 32),
                _buildSectionHeader('Account Details'),
                const SizedBox(height: 16),

                // Read-only fields
                _buildInfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: 'user@example.com', // TODO: Get from auth
                  iconColor: Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Member Since',
                  value: 'December 2024', // TODO: Format from created_at
                  iconColor: Colors.green,
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.shield_outlined,
                  label: 'Account Status',
                  value: profile.status == 'active' ? 'Active' : profile.status,
                  iconColor: profile.status == 'active' ? Colors.green : Colors.orange,
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading profile: $err'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      style: TextStyle(
        color: enabled ? AppColors.textPrimary : Colors.grey.shade600,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: enabled ? AppColors.primary : Colors.grey),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wc_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Gender',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildGenderOption('Male', 'male', Icons.male),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption('Female', 'female', Icons.female),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderOption('Other', 'other', Icons.transgender),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String label, String value, IconData icon) {
    final isSelected = _selectedGender == value;
    return InkWell(
      onTap: _isEditing ? () => setState(() => _selectedGender = value) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cake_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Age',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isEditing ? Colors.grey.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_selectedAge years old',
                style: TextStyle(
                  fontSize: 16,
                  color: _isEditing ? AppColors.textPrimary : Colors.grey.shade600,
                ),
              ),
              if (_isEditing)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: _selectedAge > 18 ? AppColors.primary : Colors.grey,
                      onPressed: _selectedAge > 18
                          ? () => setState(() => _selectedAge--)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: _selectedAge < 100 ? AppColors.primary : Colors.grey,
                      onPressed: _selectedAge < 100
                          ? () => setState(() => _selectedAge++)
                          : null,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
