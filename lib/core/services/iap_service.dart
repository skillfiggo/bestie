
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:bestie/core/services/supabase_service.dart';

final iapServiceProvider = Provider<IAPService>((ref) {
  return IAPService(ref);
});

class IAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Callback for when a purchase is completed/updated
  Function(PurchaseDetails)? onPurchaseUpdated;
  Function(String)? onError;

  IAPService(Ref ref) {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        if (onError != null) onError!(error.toString());
      },
    );
  }

  void dispose() {
    _subscription.cancel();
  }

  Future<bool> isAvailable() async {
    return await _iap.isAvailable();
  }

  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }
    return response.productDetails;
  }

  Future<void> buyProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    // For consumables (coins), always use buyConsumable
    await _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if (onError != null) onError!(purchaseDetails.error?.message ?? 'Unknown error');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          
          // Verify and Deliver
          final valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
             if (onPurchaseUpdated != null) onPurchaseUpdated!(purchaseDetails);
             // Complete the purchase process
             if (purchaseDetails.pendingCompletePurchase) {
               await _iap.completePurchase(purchaseDetails);
             }
          } else {
            if (onError != null) onError!('Invalid purchase verification');
          }
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // SECURITY: Always verify receipts on the backend!
    // We send the receipt data to Supabase Edge Function
    try {
      final response = await SupabaseService.client.functions.invoke(
        'verify-google-payment',
        body: {
          'source': 'google_play',
          'verificationData': purchaseDetails.verificationData.serverVerificationData,
          'productID': purchaseDetails.productID,
          'transactionID': purchaseDetails.purchaseID,
        }
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Verification error: $e');
      // For development/mocking purposes, we might want to return true IF we are debugging
      // But for production, return false.
      // returning false for safety.
      return false;
    }
  }
}
