import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/admin/data/repositories/system_config_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminBannerEditorScreen extends ConsumerStatefulWidget {
  const AdminBannerEditorScreen({super.key});

  @override
  ConsumerState<AdminBannerEditorScreen> createState() => _AdminBannerEditorScreenState();
}

class _AdminBannerEditorScreenState extends ConsumerState<AdminBannerEditorScreen> {
  bool _isLoading = true;
  List<String> _ads = [];
  final TextEditingController _textController = TextEditingController();
  final List<TextEditingController> _imageControllers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _textController.dispose();
    for (var controller in _imageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(systemConfigRepositoryProvider);
      final results = await Future.wait([
        repo.fetchBannerAds(),
        repo.fetchBannerImages(),
      ]);

      final ads = results[0] as List<String>;
      final images = results[1] as List<String>;

      setState(() {
        _ads = ads.isNotEmpty ? ads : [
           "🎉 Premium discounts available now!",
            "🔥 Hot matches near you!",
            "💎 Verify your profile for free badge",
            "🚀 Boost your profile to get more views",
        ];
        
        _imageControllers.clear();
        for (var img in images) {
          _imageControllers.add(TextEditingController(text: img));
        }
        // Ensure at least one field if empty
        if (_imageControllers.isEmpty) {
           _imageControllers.add(TextEditingController(text: 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1000&q=80'));
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    
    // Validation
    for (var controller in _imageControllers) {
      final text = controller.text.trim();
      if (text.contains('unsplash.com/photos/')) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invalid Image Link'),
            content: const Text(
              'It looks like you pasted a link to the Unsplash website instead of the image setup.\n\n'
              'Please go back to the website, right-click the image, and select "Copy Image Address".\n\n'
              'The link should usually start with "images.unsplash.com" or end with .jpg/.png',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
    }

    try {
      final repo = ref.read(systemConfigRepositoryProvider);
      final images = _imageControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      await Future.wait([
        repo.updateBannerAds(_ads),
        repo.updateBannerImages(images),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully')));
        _isLoading = false;
        setState(() {}); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  void _addAd() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _ads.add(text);
        _textController.clear();
      });
    }
  }

  void _removeAd(int index) {
    setState(() {
      _ads.removeAt(index);
    });
  }

  void _addImageField() {
    if (_imageControllers.length < 3) {
      setState(() {
        _imageControllers.add(TextEditingController());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 images allowed')),
      );
    }
  }

  void _removeImageField(int index) {
    setState(() {
      _imageControllers[index].dispose();
      _imageControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Banner Ads'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: AppColors.primary),
            onPressed: _isLoading ? null : _saveData,
          )
        ],
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Banner Images (Max 3)', style: TextStyle(fontWeight: FontWeight.bold)),
                          if (_imageControllers.length < 3)
                            TextButton.icon(
                              onPressed: _addImageField,
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text('Add Image'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_imageControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _imageControllers[index],
                                  decoration: InputDecoration(
                                    hintText: 'https://...',
                                    labelText: 'Image ${index + 1}',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    suffixIcon: const Icon(Icons.image),
                                  ),
                                ),
                              ),
                              if (_imageControllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeImageField(index),
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      const Text('Banner Text', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              decoration: InputDecoration(
                                hintText: 'Enter new banner text...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _addAd,
                            icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 32),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _ads.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return ListTile(
                        tileColor: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: Text(_ads[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeAd(index),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
