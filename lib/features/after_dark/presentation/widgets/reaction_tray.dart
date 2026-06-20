import 'package:flutter/material.dart';

/// Bottom sheet for paid reactions: super-like, super-comment, gifts.
class ReactionTray extends StatelessWidget {
  final Future<void> Function(String type, {String? message}) onReact;
  const ReactionTray({super.key, required this.onReact});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String type, {String? message}) onReact,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ReactionTray(onReact: onReact),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF150627),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF3B1D6E))),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Show Your Love ✨',
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Story owner earns 60% as 💎 diamonds',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12)),
          const SizedBox(height: 24),
          _ReactionOption(
            emoji: '⭐', label: 'Super Like',
            description: 'Show extra love', cost: 20, diamonds: 12,
            color: const Color(0xFFFFD700),
            onTap: () async { Navigator.pop(context); await onReact('super_like'); },
          ),
          const SizedBox(height: 10),
          _ReactionOption(
            emoji: '💬', label: 'Super Comment',
            description: 'Send a highlighted comment', cost: 50, diamonds: 30,
            color: const Color(0xFF60A5FA),
            onTap: () => _showCommentInput(context, 'super_comment'),
          ),
          const SizedBox(height: 10),
          _ReactionOption(
            emoji: '🎁', label: 'Story Gift',
            description: 'Send a gift to the storyteller', cost: 100, diamonds: 60,
            color: const Color(0xFFEC4899),
            onTap: () => _showCommentInput(context, 'gift_100'),
          ),
          const SizedBox(height: 10),
          _ReactionOption(
            emoji: '👑', label: 'Grand Gift',
            description: 'The ultimate gesture', cost: 200, diamonds: 120,
            color: const Color(0xFFF59E0B),
            onTap: () => _showCommentInput(context, 'gift_200'),
          ),
        ],
      ),
    );
  }

  void _showCommentInput(BuildContext ctx, String type) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF150627),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add a message (optional)',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 150,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write something kind...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E0B38),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF3B1D6E))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF3B1D6E))),
                  counterStyle: const TextStyle(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    Navigator.pop(ctx);
                    await onReact(type, message: controller.text.trim());
                  },
                  child: const Text('Send',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionOption extends StatelessWidget {
  final String emoji;
  final String label;
  final String description;
  final int cost;
  final int diamonds;
  final Color color;
  final VoidCallback onTap;

  const _ReactionOption({
    required this.emoji, required this.label, required this.description,
    required this.cost, required this.diamonds, required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: color,
                      fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(description,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$cost 🪙', style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 13)),
                Text('→ $diamonds 💎',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
