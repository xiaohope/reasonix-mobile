/// API 使用统计
class UsageInfo {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int? promptCacheHitTokens;

  const UsageInfo({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    this.promptCacheHitTokens,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) => UsageInfo(
    promptTokens: json['prompt_tokens'] as int? ?? 0,
    completionTokens: json['completion_tokens'] as int? ?? 0,
    totalTokens: json['total_tokens'] as int? ?? 0,
    promptCacheHitTokens: json['prompt_cache_hit_tokens'] as int?,
  );

  /// 估算费用（元，deepseek-chat 价格）
  double get estimatedCost {
    // deepseek-chat: 输入 ¥0.001/1K, 输出 ¥0.002/1K (约)
    final input = (promptTokens - (promptCacheHitTokens ?? 0)).clamp(0, promptTokens) * 0.000001;
    final output = completionTokens * 0.000002;
    return input + output;
  }
}
