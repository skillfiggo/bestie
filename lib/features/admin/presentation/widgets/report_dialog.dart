import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/admin/data/repositories/reports_repository.dart';

class ReportDialog extends ConsumerStatefulWidget {
  final String reportedUserId;
  final String reportType; // 'user', 'message', 'profile'
  final String? reportedMessageId;
  final String reportedUserName;

  const ReportDialog({
    super.key,
    required this.reportedUserId,
    required this.reportType,
    required this.reportedUserName,
    this.reportedMessageId,
  });

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  String? _selectedReason;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _reasons = [
    {'value': 'spam', 'label': 'Spam', 'icon': Icons.report},
    {'value': 'harassment', 'label': 'Harassment', 'icon': Icons.warning},
    {'value': 'inappropriate_content', 'label': 'Inappropriate Content', 'icon': Icons.block},
    {'value': 'fake_profile', 'label': 'Fake Profile', 'icon': Icons.person_off},
    {'value': 'underage', 'label': 'Underage User', 'icon': Icons.child_care},
    {'value': 'violence', 'label': 'Violence', 'icon': Icons.dangerous},
    {'value': 'hate_speech', 'label': 'Hate Speech', 'icon': Icons.speaker_notes_off},
    {'value': 'sexual_content', 'label': 'Sexual Content', 'icon': Icons.no_adult_content},
    {'value': 'scam', 'label': 'Scam/Fraud', 'icon': Icons.money_off},
    {'value': 'other', 'label': 'Other', 'icon': Icons.flag},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(reportsRepositoryProvider).submitReport(
        reportedUserId: widget.reportedUserId,
        reportType: widget.reportType,
        reason: _selectedReason!,
        description: _descriptionController.text.trim(),
        reportedMessageId: widget.reportedMessageId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully. We\'ll review it shortly.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flag, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report User',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.reportedUserName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Why are you reporting this?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _reasons.length,
                itemBuilder: (context, index) {
                  final reason = _reasons[index];
                  final isSelected = _selectedReason == reason['value'];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
                    ),
                    child: RadioListTile<String>(
                      value: reason['value'],
                      groupValue: _selectedReason,
                      onChanged: (value) {
                        setState(() => _selectedReason = value);
                      },
                      title: Row(
                        children: [
                          Icon(
                            reason['icon'],
                            size: 20,
                            color: isSelected ? AppColors.primary : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            reason['label'],
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      activeColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Additional details (optional)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Report',
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
}

/// Helper function to show report dialog
void showReportDialog(
  BuildContext context, {
  required String reportedUserId,
  required String reportedUserName,
  String reportType = 'user',
  String? reportedMessageId,
}) {
  showDialog(
    context: context,
    builder: (context) => ReportDialog(
      reportedUserId: reportedUserId,
      reportedUserName: reportedUserName,
      reportType: reportType,
      reportedMessageId: reportedMessageId,
    ),
  );
}
