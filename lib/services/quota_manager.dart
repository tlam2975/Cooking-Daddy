import 'ai_interface.dart';
import 'gemini_service.dart';

/// Manages AI quota from server
class QuotaManager {
  final AIInterface _aiService = GeminiService();

  /// Get current quota from server
  Future<QuotaInfo?> getQuota() async {
    return await _aiService.getQuota();
  }

  /// Check if quota is available
  Future<bool> hasQuota() async {
    final quota = await getQuota();
    return quota != null && quota.remaining > 0;
  }

  /// Get quota remaining as percentage
  Future<double> getQuotaPercentage() async {
    final quota = await getQuota();
    if (quota == null || quota.limit == 0) return 0;
    return quota.remaining / quota.limit;
  }
}
