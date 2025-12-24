import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/admin/data/repositories/admin_repository.dart';
import 'package:bestie/features/admin/domain/models/broadcast_model.dart';
import 'package:intl/intl.dart';

class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  bool _isLoading = false;
  List<BroadcastModel> _broadcasts = [];

  @override
  void initState() {
    super.initState();
    _loadBroadcasts();
  }

  Future<void> _loadBroadcasts() async {
    setState(() => _isLoading = true);
    try {
      final broadcasts = await ref.read(adminRepositoryProvider).getBroadcasts();
      if (mounted) {
        setState(() {
          _broadcasts = broadcasts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _createBroadcast() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final imageUrlController = TextEditingController();
    final linkUrlController = TextEditingController();
    final linkTextController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Broadcast'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Important Announcement',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message Body',
                hintText: 'Enter your announcement here...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL (Optional)',
                hintText: 'https://example.com/image.png',
                prefixIcon: Icon(Icons.image),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: linkUrlController,
              decoration: const InputDecoration(
                labelText: 'Action Link (Optional)',
                hintText: 'https://example.com',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: linkTextController,
              decoration: const InputDecoration(
                labelText: 'Link Button Text',
                hintText: 'e.g., Learn More',
                prefixIcon: Icon(Icons.abc),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty && messageController.text.isNotEmpty) {
                Navigator.pop(context);
                try {
                  await ref.read(adminRepositoryProvider).createBroadcast(
                        title: titleController.text.trim(),
                        message: messageController.text.trim(),
                        imageUrl: imageUrlController.text.trim().isEmpty ? null : imageUrlController.text.trim(),
                        linkUrl: linkUrlController.text.trim().isEmpty ? null : linkUrlController.text.trim(),
                        linkText: linkTextController.text.trim().isEmpty ? null : linkTextController.text.trim(),
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Broadcast sent successfully!')),
                    );
                    _loadBroadcasts();
                  }
                } catch (e) {
                   if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                   }
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivateBroadcast(String id) async {
    try {
      await ref.read(adminRepositoryProvider).deactivateBroadcast(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Broadcast deactivated')),
        );
        _loadBroadcasts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Broadcast Messages',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBroadcast,
        label: const Text('New Broadcast'),
        icon: const Icon(Icons.send),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _broadcasts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No broadcasts sent yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _broadcasts.length,
                  itemBuilder: (context, index) {
                    final broadcast = _broadcasts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    broadcast.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                if (broadcast.isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('ACTIVE', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('INACTIVE', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              broadcast.message,
                              style: TextStyle(color: Colors.grey.shade800, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMM d, y • h:mm a').format(broadcast.createdAt),
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                ),
                                if (broadcast.isActive)
                                  TextButton.icon(
                                    onPressed: () => _deactivateBroadcast(broadcast.id),
                                    icon: const Icon(Icons.stop_circle_outlined, color: Colors.red, size: 16),
                                    label: const Text('Deactivate', style: TextStyle(color: Colors.red)),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
