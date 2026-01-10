import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/moment/data/providers/moment_providers.dart';
import 'package:bestie/core/services/supabase_service.dart';

class CommentsSheet extends ConsumerStatefulWidget {
  final String momentId;

  const CommentsSheet({super.key, required this.momentId});

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final supabase = SupabaseService.client;
  bool _isLoading = false;

  // Alternative: Just use Future for MVP comments list to allow joins
  Future<List<Map<String, dynamic>>> _fetchComments() async {
    final response = await supabase
        .from('moment_comments')
        .select('*, profiles(*)')
        .eq('moment_id', widget.momentId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('moment_comments').insert({
        'moment_id': widget.momentId,
        'user_id': user.id,
        'content': content,
      });
      
      // Update comment count on moment manually/optimistically or via RPC
      try {
        await supabase.rpc('increment_comments', params: {'t_name': 'moments', 'row_id': widget.momentId});
      } catch (_) {
         // Fallback manual update
         final moment = await supabase.from('moments').select('comments_count').eq('id', widget.momentId).single();
         int currentComments = moment['comments_count'] as int;
         await supabase.from('moments').update({'comments_count': currentComments + 1}).eq('id', widget.momentId);
      }

      _commentController.clear();
      // Refetch comments
      setState(() {});
      // Refresh global feed to update comment counts
      ref.invalidate(momentsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Comments',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(),
          
          // Comments List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchComments(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final comments = snapshot.data ?? [];
                
                if (comments.isEmpty) {
                  return Center(
                    child: Text(
                      'No comments yet.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final profile = comment['profiles'];
                    final name = profile?['name'] ?? 'Unknown';
                    final avatarUrl = profile?['avatar_url'] ?? '';
                    final content = comment['content'] ?? '';
                    final createdAt = DateTime.parse(comment['created_at']);
                    
                    // Simple logic for time display
                    final timeAgo = DateTime.now().difference(createdAt).inMinutes < 60
                        ? '${DateTime.now().difference(createdAt).inMinutes}m'
                        : '${DateTime.now().difference(createdAt).inHours}h';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      timeAgo,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  content,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87, // Darker color for visibility
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _postComment,
                  icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
