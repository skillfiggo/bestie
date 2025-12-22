import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';

class WithdrawDiamondsScreen extends StatefulWidget {
  const WithdrawDiamondsScreen({super.key});

  @override
  State<WithdrawDiamondsScreen> createState() => _WithdrawDiamondsScreenState();
}

class _WithdrawDiamondsScreenState extends State<WithdrawDiamondsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String _selectedMethod = 'PayPal';
  
  final int _currentDiamonds = 1050;
  final double _conversionRate = 0.01; // $0.01 per diamond

  final List<String> _withdrawalMethods = [
    'PayPal',
    'Bank Transfer',
    'Stripe',
    'Cash App',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _maxWithdrawal => _currentDiamonds * _conversionRate;

  void _handleWithdraw() {
    if (_formKey.currentState!.validate()) {
      final amount = int.tryParse(_amountController.text) ?? 0;
      final usdAmount = amount * _conversionRate;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Withdrawal request submitted: $amount diamonds (\$${usdAmount.toStringAsFixed(2)}) via $_selectedMethod',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // TODO: Implement actual withdrawal processing
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Current Balance
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Available Balance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.diamond, color: Colors.white, size: 32),
                      const SizedBox(width: 8),
                      Text(
                        '$_currentDiamonds',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Diamonds',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '≈ \$${_maxWithdrawal.toStringAsFixed(2)} USD',
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

            // Withdrawal Amount
            const Text(
              'Withdrawal Amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Enter diamond amount',
                hintText: 'Min: 100 diamonds',
                prefixIcon: const Icon(Icons.diamond, color: Colors.blue),
                suffixText: 'diamonds',
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = int.tryParse(value);
                if (amount == null) {
                  return 'Please enter a valid number';
                }
                if (amount < 100) {
                  return 'Minimum withdrawal is 100 diamonds';
                }
                if (amount > _currentDiamonds) {
                  return 'Insufficient balance';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {}); // Update USD preview
              },
            ),
            const SizedBox(height: 8),
            if (_amountController.text.isNotEmpty)
              Text(
                'You will receive: \$${((int.tryParse(_amountController.text) ?? 0) * _conversionRate).toStringAsFixed(2)} USD',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 32),

            // Withdrawal Method
            const Text(
              'Withdrawal Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ..._withdrawalMethods.map((method) {
              final isSelected = _selectedMethod == method;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMethod = method;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.primary.withOpacity(0.1) 
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getMethodIcon(method),
                        color: isSelected ? AppColors.primary : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        method,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 32),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Withdrawal Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Minimum withdrawal: 100 diamonds\n'
                    '• Conversion rate: 1 diamond = \$${_conversionRate.toStringAsFixed(2)}\n'
                    '• Processing time: 3-5 business days\n'
                    '• No withdrawal fees',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Withdraw Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _handleWithdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Submit Withdrawal Request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'PayPal':
        return Icons.paypal;
      case 'Bank Transfer':
        return Icons.account_balance;
      case 'Stripe':
        return Icons.credit_card;
      case 'Cash App':
        return Icons.attach_money;
      default:
        return Icons.payment;
    }
  }
}
