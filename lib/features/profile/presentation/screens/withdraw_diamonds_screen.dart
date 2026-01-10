import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/profile/data/repositories/withdrawal_repository.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';

class WithdrawDiamondsScreen extends ConsumerStatefulWidget {
  const WithdrawDiamondsScreen({super.key});

  @override
  ConsumerState<WithdrawDiamondsScreen> createState() => _WithdrawDiamondsScreenState();
}

class _WithdrawDiamondsScreenState extends ConsumerState<WithdrawDiamondsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  
  String? _selectedBankCode;
  String? _selectedBankName;
  String? _resolvedAccountName;
  bool _isLoadingBanks = true;
  bool _isResolvingAccount = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _banks = [];

  // Conversion: 1 Diamond = 1.5 Naira (Adjustable based on platform policy)
  final double _conversionRate = 1.5;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await ref.read(withdrawalRepositoryProvider).getBanks();
      if (mounted) {
        setState(() {
          _banks = banks;
          _isLoadingBanks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBanks = false);
      }
    }
  }

  Future<void> _resolveAccount() async {
    if (_accountNumberController.text.length == 10 && _selectedBankCode != null) {
      setState(() => _isResolvingAccount = true);
      try {
        final name = await ref.read(withdrawalRepositoryProvider).resolveAccount(
          _accountNumberController.text,
          _selectedBankCode!,
        );
        if (mounted) {
          setState(() {
            _resolvedAccountName = name;
            _isResolvingAccount = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isResolvingAccount = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _handleWithdraw() async {
    if (!_formKey.currentState!.validate()) return;
    if (_resolvedAccountName == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your account details first')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      final diamonds = int.parse(_amountController.text);
      final nairaAmount = diamonds * _conversionRate;

      await ref.read(withdrawalRepositoryProvider).submitRequest(
        diamonds: diamonds,
        nairaAmount: nairaAmount,
        bankName: _selectedBankName!,
        accountNumber: _accountNumberController.text,
        accountName: _resolvedAccountName!,
        bankCode: _selectedBankCode!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal request submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(userProfileProvider); // Refresh balance
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final currentDiamonds = profileAsync.value?.diamonds ?? 0;

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
          'Withdraw Earnings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Current Balance
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Available Diamonds',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.diamond, color: Colors.white, size: 32),
                        const SizedBox(width: 8),
                        Text(
                          '$currentDiamonds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '≈ ₦${(currentDiamonds * _conversionRate).toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Withdrawal Amount',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter diamond amount (Min: 100)',
                  prefixIcon: const Icon(Icons.diamond, color: Colors.purple),
                  suffixText: 'Diamonds',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter amount';
                  final amount = int.tryParse(value);
                  if (amount == null) return 'Invalid number';
                  if (amount < 100) return 'Min: 100 diamonds';
                  if (amount > currentDiamonds) return 'Insufficient balance';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              const Text(
                'Bank Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              // Select Bank
              _isLoadingBanks 
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _selectedBankCode,
                      decoration: InputDecoration(
                        hintText: 'Select Bank',
                        prefixIcon: const Icon(Icons.account_balance),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _banks.map((bank) {
                        return DropdownMenuItem<String>(
                          value: bank['code'],
                          child: Text(bank['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBankCode = value;
                          _selectedBankName = _banks.firstWhere((b) => b['code'] == value)['name'];
                          _resolvedAccountName = null;
                        });
                        _resolveAccount();
                      },
                      validator: (value) => value == null ? 'Select bank' : null,
                    ),
              const SizedBox(height: 16),

              // Account Number
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: InputDecoration(
                  hintText: 'Account Number',
                  prefixIcon: const Icon(Icons.numbers),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: _isResolvingAccount ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ) : null,
                ),
                onChanged: (value) {
                  if (value.length == 10) _resolveAccount();
                  else setState(() => _resolvedAccountName = null);
                },
                validator: (value) => (value?.length ?? 0) < 10 ? 'Enter 10 digits' : null,
              ),

              if (_resolvedAccountName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _resolvedAccountName!,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 48),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _isResolvingAccount) ? null : _handleWithdraw,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Withdrawal Request',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Requests are reviewed within 24-48 hours',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
