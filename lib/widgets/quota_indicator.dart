import 'package:flutter/material.dart';
import '../services/quota_manager.dart';
import '../services/ai_interface.dart';

/// Widget to display AI quota
class QuotaIndicator extends StatefulWidget {
  const QuotaIndicator({super.key});

  @override
  State<QuotaIndicator> createState() => _QuotaIndicatorState();
}

class _QuotaIndicatorState extends State<QuotaIndicator> {
  final QuotaManager _quotaManager = QuotaManager();
  QuotaInfo? _quota;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    final quota = await _quotaManager.getQuota();
    if (mounted) {
      setState(() {
        _quota = quota;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Loading...'),
          ],
        ),
      );
    }

    if (_quota == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text('Server offline'),
          ],
        ),
      );
    }

    final percentage = _quota!.remaining / _quota!.limit;
    final color = percentage > 0.5
        ? const Color.fromARGB(255, 85, 248, 161)
        : percentage > 0.2
        ? const Color.fromARGB(255, 255, 166, 33)
        : const Color.fromARGB(255, 255, 70, 57);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '${_quota!.remaining}/${_quota!.limit} left',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
