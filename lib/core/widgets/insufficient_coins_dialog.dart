import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/profile/presentation/screens/recharge_coins_screen.dart';

/// Shows a premium "Not enough Coin" popup with Recharge / Cancel buttons.
///
/// [isVideo] drives the icon and the required-coins hint in the subtitle.
/// [isReceiver] switches the subtitle copy between "start" and "accept".
void showInsufficientCoinsDialog(
  BuildContext context, {
  required bool isVideo,
  bool isReceiver = false,
}) {
  final int required = isVideo ? 200 : 100;
  final String callType = isVideo ? 'video' : 'voice';
  final String action = isReceiver ? 'accept' : 'start';

  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: _InsufficientCoinsContent(
        required: required,
        callType: callType,
        action: action,
      ),
    ),
  );
}

class _InsufficientCoinsContent extends StatelessWidget {
  final int required;
  final String callType;
  final String action;

  const _InsufficientCoinsContent({
    required this.required,
    required this.callType,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top accent bar ──────────────────────────────────────
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFf97316), Color(0xFFefb744)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),

          const SizedBox(height: 28),

          // ── Coin icon ───────────────────────────────────────────
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFffe082), Color(0xFFf97316)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFf97316).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/images/icons/coin_balance_icon.png',
                width: 60,
                height: 60,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Title ───────────────────────────────────────────────
          const Text(
            'Not enough Coin',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 10),

          // ── Subtitle ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'You need at least $required coins to $action a $callType call.\nPlease recharge your wallet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Required badge ──────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFfff8ee),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFf97316).withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/icons/coin_balance_icon.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '$required coins required / minute',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFf97316),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Buttons ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                // Cancel
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Recharge
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RechargeCoinsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFf97316), Color(0xFFefb744)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFf97316).withValues(alpha: 0.40),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Recharge',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
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
