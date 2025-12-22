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
  final TextEditingController _imageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _textController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(systemConfigRepositoryProvider);
      final results = await Future.wait([
        repo.fetchBannerAds(),
        repo.fetchBannerImage(),
      ]);

      final ads = results[0] as List<String>;
      final image = results[1] as String;

      setState(() {
        _ads = ads.isNotEmpty ? ads : [
           "🎉 Premium discounts available now!",
            "🔥 Hot matches near you!",
            "💎 Verify your profile for free badge",
            "🚀 Boost your profile to get more views",
        ];
        _imageController.text = image;
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
    try {
      final repo = ref.read(systemConfigRepositoryProvider);
      await Future.wait([
        repo.updateBannerAds(_ads),
        repo.updateBannerImage(_imageController.text.trim()),
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
                      const Text('Banner Image URL', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _imageController,
                        decoration: InputDecoration(
                          hintText: 'https://...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: const Icon(Icons.image),
                        ),
                      ),
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
