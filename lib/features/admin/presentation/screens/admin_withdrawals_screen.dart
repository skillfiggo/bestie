import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/profile/data/repositories/withdrawal_repository.dart';
import 'package:intl/intl.dart';

class AdminWithdrawalsScreen extends ConsumerStatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  ConsumerState<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends ConsumerState<AdminWithdrawalsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  final _currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await ref.read(withdrawalRepositoryProvider).getPendingRequests();
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processRequest(Map<String, dynamic> request, bool approve) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve Withdrawal' : 'Reject Withdrawal'),
        content: Text(approve 
          ? 'This will initiate a Paystack transfer of ${_currencyFormat.format(request['amount_naira'])} to ${request['account_name']}. Are you sure?'
          : 'This will reject the request and refund diamonds to the user.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: approve ? AppColors.success : AppColors.error),
            child: Text(approve ? 'Approve & Pay' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(withdrawalRepositoryProvider).processRequest(request['id'], approve);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(approve ? 'Payment initiated' : 'Request rejected'), backgroundColor: AppColors.success),
          );
          _fetchRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Withdrawals'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRequests),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _requests.isEmpty 
          ? const Center(child: Text('No pending requests'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final request = _requests[index];
                final profile = request['profiles'];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(profile['avatar_url'] ?? ''),
                              radius: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(profile['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('ID: ${profile['bestie_id']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(
                              _currencyFormat.format(request['amount_naira']),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildInfoRow('Bank', request['bank_name']),
                        _buildInfoRow('Account', request['account_number']),
                        _buildInfoRow('Name', request['account_name']),
                        _buildInfoRow('Diamonds', '${request['amount_diamonds']} 💎'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _processRequest(request, false),
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _processRequest(request, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                                child: const Text('Approve & Pay'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }
}
