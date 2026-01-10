
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/core/services/payment_service.dart';
import 'package:bestie/core/services/iap_service.dart';
import 'package:bestie/features/profile/data/repositories/profile_repository.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class RechargeCoinsScreen extends ConsumerStatefulWidget {
  const RechargeCoinsScreen({super.key});

  @override
  ConsumerState<RechargeCoinsScreen> createState() => _RechargeCoinsScreenState();
}

class _RechargeCoinsScreenState extends ConsumerState<RechargeCoinsScreen> {
  int? _selectedPackage;
  bool _isLoading = false;
  bool _isStoreAvailable = false;
  List<ProductDetails> _storeProducts = [];

  // Define Google Play Product IDs and their corresponding Coin values
  // This allows for "different coin rates" (Coins per Price) than Paystack.
  static const Map<String, int> _googleProductCoins = {
    'bestie_coins_tier1': 1200,   // Included 200 bonus
    'bestie_coins_tier2': 2000,
    'bestie_coins_tier3': 5000,
    'bestie_coins_tier4': 10000,
  };

  // Fallback (Paystack) Packages
  final List<Map<String, dynamic>> _paystackPackages = [
    {'coins': 1000, 'price': 1800, 'bonus': 200},
    {'coins': 2100, 'price': 3500, 'bonus': 0},
    {'coins': 5200, 'price': 8500, 'bonus': 0},
    {'coins': 10500, 'price': 17000, 'bonus': 0},
  ];

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _initializeIAP();
  }

  Future<void> _initializeIAP() async {
    // Only check for IAP on mobile
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final iapService = ref.read(iapServiceProvider);
    final available = await iapService.isAvailable();

    if (available) {
      // 1. Setup specific listeners for this screen
      iapService.onPurchaseUpdated = _handleIAPSuccess;
      iapService.onError = (error) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google Play Error: $error'), backgroundColor: AppColors.error),
          );
          setState(() => _isLoading = false);
        }
      };

      // 2. Load Products
      try {
        final products = await iapService.loadProducts(_googleProductCoins.keys.toSet());
        // Sort products by price if possible
        products.sort((a, b) => a.id.compareTo(b.id));

        if (mounted) {
          setState(() {
            _isStoreAvailable = true;
            _storeProducts = products;
          });
        }
      } catch (e) {
        debugPrint("Error loading IAP products: $e");
      }
    }
  }
  
  void _handleIAPSuccess(PurchaseDetails purchase) async {
    // Purchase verified by Service.
    // UI Feedback
    if (mounted) {
       setState(() => _isLoading = false);
       ref.invalidate(userProfileProvider); // Refresh balance
       
       final coins = _googleProductCoins[purchase.productID] ?? 0;
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully purchased $coins coins!'),
            backgroundColor: AppColors.success,
          ),
       );
       Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    // Clean up callbacks
    // Ideally we might want to keep the subscription alive globally, 
    // but for this screen-specific logic we can just detach our specific callbacks
    super.dispose();
  }

  Future<void> _handlePurchase() async {
    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a package'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_isStoreAvailable && _storeProducts.isNotEmpty) {
      // Handle Google/Apple IAP
      await _initiateIAPPurchase();
    } else {
      // Handle Paystack
      await _initiatePaystackPurchase();
    }
  }

  Future<void> _initiateIAPPurchase() async {
    setState(() => _isLoading = true);
    try {
      final product = _storeProducts[_selectedPackage!];
      await ref.read(iapServiceProvider).buyProduct(product);
      // The process continues in `_handleIAPSuccess`
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start purchase: $e')),
        );
      }
    }
  }

  Future<void> _initiatePaystackPurchase() async {
    final package = _paystackPackages[_selectedPackage!];
    final amount = package['price'] as int;
    final coinsToAdd = (package['coins'] as int) + (package['bonus'] as int);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User email not found. Please update profile.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Initiate Charge on Client
      final reference = await ref.read(paymentServiceProvider).chargeCard(
        context: context,
        amount: amount,
        email: user.email!,
      );

      if (reference != null && mounted) {
        // 2. Verify Charge on Server
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verifying payment...')),
        );
        
        final success = await ref.read(paymentServiceProvider).verifyPayment(
          context: context,
          reference: reference,
        );
        
        if (success && mounted) {
          ref.invalidate(userProfileProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully purchased $coinsToAdd coins!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase process failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _fetchCurrentBalance() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
        final profile = await ref.read(profileRepositoryProvider).getProfileById(user.id);
        return profile?.coins ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Determine which list to show
    final showIAP = _isStoreAvailable && _storeProducts.isNotEmpty;
    final itemCount = showIAP ? _storeProducts.length : _paystackPackages.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Recharge Coins',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Current Balance
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade400, Colors.amber.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.white, size: 32),
                    const SizedBox(width: 8),
                    FutureBuilder<int>(
                      future: _fetchCurrentBalance(),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.hasData ? '${snapshot.data}' : '...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                    ),
                  ],
                ),
                const Text(
                  'Coins',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          if (showIAP)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Google Play Store", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ),

          // Packages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                // Determine data for this item based on source (IAP vs Paystack)
                String displayPrice;
                int coinsAmount;
                int bonusAmount = 0;

                if (showIAP) {
                   final product = _storeProducts[index];
                   displayPrice = product.price; // e.g. "₦2,000" or "$2.99" from Store
                   coinsAmount = _googleProductCoins[product.id] ?? 0;
                   // We don't have explicit bonus logic for IAP unless we map it, assuming 0 for now
                } else {
                   final package = _paystackPackages[index];
                   displayPrice = _currencyFormat.format(package['price']);
                   coinsAmount = package['coins'] as int;
                   bonusAmount = package['bonus'] as int;
                }

                final isSelected = _selectedPackage == index;
                final totalCoins = coinsAmount + bonusAmount;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPackage = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primary.withValues(alpha: 0.1) 
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Coin Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.monetization_on,
                            color: Colors.amber.shade700,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Package Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Text(
                                      '$coinsAmount Coins',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (bonusAmount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '+$bonusAmount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (bonusAmount > 0 || showIAP) // For IAP we might show description
                                Text(
                                  showIAP ? '${_storeProducts[index].description}' : 'Total: $totalCoins coins',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Price
                        Text(
                          displayPrice,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Purchase Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handlePurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(
                    _selectedPackage == null
                        ? 'Select a Package'
                        : 'Purchase for ${
                           showIAP 
                           ? _storeProducts[_selectedPackage!].price
                           : _currencyFormat.format(_paystackPackages[_selectedPackage!]['price'])
                        }', 
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
