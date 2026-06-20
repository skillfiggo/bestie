import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bestie/features/after_dark/domain/models/after_dark_models.dart';

/// Displays tonight's topic with a countdown timer to the next midnight reveal.
class TopicBanner extends StatefulWidget {
  final AfterDarkTopic topic;
  final bool hasPostedToday;
  final VoidCallback onWrite;

  const TopicBanner({
    super.key,
    required this.topic,
    required this.hasPostedToday,
    required this.onWrite,
  });

  @override
  State<TopicBanner> createState() => _TopicBannerState();
}

class _TopicBannerState extends State<TopicBanner> {
  late Timer _timer;
  late Duration _timeLeft;

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _updateTimeLeft());
    });
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timeLeft = midnight.difference(now);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = _pad(_timeLeft.inHours);
    final m = _pad(_timeLeft.inMinutes.remainder(60));
    final s = _pad(_timeLeft.inSeconds.remainder(60));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0533), Color(0xFF3B0764)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Star decorations
          Positioned(
            right: 16,
            top: 16,
            child: Icon(Icons.auto_awesome,
                size: 40,
                color: Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            right: 60,
            bottom: 10,
            child: Icon(Icons.star,
                size: 16,
                color: Colors.white.withValues(alpha: 0.12)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.nights_stay_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Tonight\'s Topic',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Countdown
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 11,
                              color: Color(0xFFC084FC)),
                          const SizedBox(width: 4),
                          Text('$h:$m:$s',
                              style: const TextStyle(
                                color: Color(0xFFC084FC),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Topic text
                Text(
                  '"${widget.topic.topic}"',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),

                // Write button
                GestureDetector(
                  onTap: widget.hasPostedToday ? null : widget.onWrite,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: widget.hasPostedToday
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                            ),
                      color: widget.hasPostedToday
                          ? Colors.white.withValues(alpha: 0.1)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.hasPostedToday
                                ? Icons.check_circle_rounded
                                : Icons.edit_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.hasPostedToday
                                ? 'Story Submitted — Awaiting Review'
                                : 'Write Your Story',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
