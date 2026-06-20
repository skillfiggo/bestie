import 'package:flutter/material.dart';

/// Bottom sheet for sending an anonymous compliment (10 coins).
class AnonComplimentSheet extends StatefulWidget {
  final Future<void> Function(String message) onSend;

  const AnonComplimentSheet({super.key, required this.onSend});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String message) onSend,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AnonComplimentSheet(onSend: onSend),
    );
  }

  @override
  State<AnonComplimentSheet> createState() => _AnonComplimentSheetState();
}

class _AnonComplimentSheetState extends State<AnonComplimentSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF150627),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF3B1D6E))),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('💌  Anonymous Compliment',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'They will never know it\'s you — costs 10 🪙',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              maxLength: 200,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write something heartfelt...',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E0B38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF3B1D6E)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF3B1D6E)),
                ),
                counterStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _sending
                    ? null
                    : () async {
                        final msg = _ctrl.text.trim();
                        if (msg.isEmpty) return;
                        setState(() => _sending = true);
                        try {
                          await widget.onSend(msg);
                          if (context.mounted) Navigator.pop(context);
                        } finally {
                          if (mounted) setState(() => _sending = false);
                        }
                      },
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Send Anonymously',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
