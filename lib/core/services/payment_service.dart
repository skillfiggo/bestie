import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestie/core/services/supabase_service.dart';
import 'dart:io';
import 'package:webview_flutter/webview_flutter.dart';

final paymentServiceProvider = Provider((ref) => PaymentService());

class PaymentService {

  Future<bool> verifyPayment({
    required BuildContext context,
    required String reference,
  }) async {
    try {
      final response = await SupabaseService.client.functions.invoke(
        'verify-payment',
        body: {'reference': reference},
      );
      
      final data = response.data;
      if (data != null && data['success'] == true) {
         return true;
      } else {
         debugPrint('Verification failed signature: ${response.data}');
         return false;
      }
    } catch (e) {
      debugPrint('Error verifying payment: $e');
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Payment verification failed: $e. Please contact support if you were charged.')),
         );
      }
      return false;
    }
  }

  /// Initialize transaction on server then show payment page
  /// This is the SECURE way - secret key stays on server
  Future<String?> chargeCard({
    required BuildContext context,
    required int amount, 
    required String email,
    String? reference,
  }) async {
    final txRef = reference ?? _getReference();

    try {
      // Step 1: Initialize transaction on SERVER (using secret key)
      final initResponse = await SupabaseService.client.functions.invoke(
        'initialize-payment',
        body: {
          'email': email,
          'amount': amount * 100, // Convert to kobo
          'reference': txRef,
        },
      );

      if (initResponse.data == null || initResponse.data['status'] != true) {
        throw Exception('Failed to initialize payment');
      }

      final authorizationUrl = initResponse.data['data']['authorization_url'] as String;
      
      if (!context.mounted) return null;

      // Step 2: Show payment page in WebView
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaystackWebView(
            authorizationUrl: authorizationUrl,
            reference: txRef,
          ),
        ),
      );

      return (result == true) ? txRef : null;
    } catch (e) {
      debugPrint('Payment failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment initialization failed: $e')),
        );
      }
      return null;
    }
  }

  String _getReference() {
    String platform;
    if (Platform.isIOS) {
      platform = 'iOS';
    } else {
      platform = 'Android';
    }
    final thisDate = DateTime.now().millisecondsSinceEpoch;
    return 'ChargedFrom${platform}_$thisDate';
  }
}

// Simple WebView for Paystack payment
class PaystackWebView extends StatefulWidget {
  final String authorizationUrl;
  final String reference;

  const PaystackWebView({
    super.key,
    required this.authorizationUrl,
    required this.reference,
  });

  @override
  State<PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<PaystackWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://your-app.com/payment-callback')) {
              // Payment completed (or at least redirected)
              Navigator.pop(context, true); 
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false), // User cancelled
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
