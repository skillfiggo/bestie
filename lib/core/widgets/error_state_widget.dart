import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/core/services/connectivity_service.dart';

class ErrorStateWidget extends StatelessWidget {
  final dynamic error;
  final VoidCallback? onRetry;
  final String? message;

  const ErrorStateWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final errorMsg = message ?? ConnectivityService.getNetworkErrorMessage(error);
    final isNetwork = error.toString().toLowerCase().contains('socketexception') ||
        error.toString().toLowerCase().contains('failed host lookup') ||
        error.toString().toLowerCase().contains('no address associated') ||
        error.toString().toLowerCase().contains('network') ||
        error.toString().toLowerCase().contains('connection');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isNetwork 
                    ? AppColors.primary.withValues(alpha: 0.1) 
                    : AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 64,
                color: isNetwork ? AppColors.primary : AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isNetwork ? 'Connection Error' : 'Something went wrong',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              errorMsg.replaceAll('🌐 ', '').replaceAll('⏱️ ', '').replaceAll('🔒 ', '').replaceAll('❌ ', ''),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
