import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/after_dark/domain/models/after_dark_models.dart';
import 'package:bestie/features/after_dark/data/providers/after_dark_providers.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';

class AfterDarkWriteScreen extends ConsumerStatefulWidget {
  final AfterDarkTopic topic;
  const AfterDarkWriteScreen({super.key, required this.topic});

  @override
  ConsumerState<AfterDarkWriteScreen> createState() =>
      _AfterDarkWriteScreenState();
}

class _AfterDarkWriteScreenState
    extends ConsumerState<AfterDarkWriteScreen> {
  final _ctrl = TextEditingController();
  bool _isAnonymous = false;
  bool _submitting = false;
  static const int _minChars = 50;
  static const int _maxChars = 1000;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int get _charCount => _ctrl.text.length;
  bool get _canSubmit =>
      _charCount >= _minChars && _charCount <= _maxChars && !_submitting;

  Future<void> _submit() async {
    final userId =
        ref.read(authRepositoryProvider).getCurrentUser()?.id;
    if (userId == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(afterDarkRepoProvider).postStory(
            userId: userId,
            topicId: widget.topic.id,
            content: _ctrl.text.trim(),
            isAnonymous: _isAnonymous,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '🌙 Story submitted! It will appear once reviewed by our team.'),
            backgroundColor: Color(0xFF7C3AED),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0118),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0118),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Write Your Story',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    'Post',
                    style: TextStyle(
                      color: _canSubmit
                          ? const Color(0xFFC084FC)
                          : Colors.white30,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Tonight's topic reference ─────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E0B38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.nights_stay_rounded,
                        color: Color(0xFFC084FC), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "Tonight's Topic",
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '"${widget.topic.topic}"',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Story input ───────────────────────────────────
          TextField(
            controller: _ctrl,
            maxLength: _maxChars,
            maxLines: null,
            minLines: 8,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.7,
            ),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
                  'Write your story here...\n\nBe honest. Be vivid. Be yourself.',
              hintStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.25), height: 1.7),
              filled: true,
              fillColor: const Color(0xFF1E0B38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF3B1D6E)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF3B1D6E)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF7C3AED)),
              ),
              counterStyle: TextStyle(
                color: _charCount < _minChars
                    ? Colors.orange
                    : Colors.white38,
              ),
            ),
          ),

          if (_charCount < _minChars && _charCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${_minChars - _charCount} more characters needed',
                style: const TextStyle(
                    color: Colors.orange, fontSize: 12),
              ),
            ),

          const SizedBox(height: 20),

          // ── Anonymous toggle ──────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E0B38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _isAnonymous
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                      : const Color(0xFF3B1D6E).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Text('🎭', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Post Anonymously',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        'Your name and photo will be hidden from everyone.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isAnonymous,
                  onChanged: (v) => setState(() => _isAnonymous = v),
                  activeColor: const Color(0xFF7C3AED),
                  activeTrackColor:
                      const Color(0xFF7C3AED).withValues(alpha: 0.3),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Content policy reminder ───────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📋  Community Guidelines',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _PolicyLine('✅  Romantic, flirty, and confessional stories'),
                _PolicyLine('✅  Mature themes and spicy storytelling'),
                _PolicyLine('❌  Graphic sexual descriptions'),
                _PolicyLine('❌  Content involving minors'),
                const SizedBox(height: 8),
                Text(
                  'All stories are reviewed by our team before appearing in the feed.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PolicyLine extends StatelessWidget {
  final String text;
  const _PolicyLine(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(text,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
      );
}
