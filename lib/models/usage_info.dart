/// API 使用统计
class UsageInfo {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int promptCacheHitTokens;

  const UsageInfo({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    this.promptCacheHitTokens = 0,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) {
    return UsageInfo(
      promptTokens: json['prompt_tokens'] as int? ?? 0,
      completionTokens: json['completion_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int? ?? 0,
      promptCacheHitTokens: json['prompt_cache_hit_tokens'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'prompt_tokens': promptTokens,
    'completion_tokens': completionTokens,
    'total_tokens': totalTokens,
    'prompt_cache_hit_tokens': promptCacheHitTokens,
  };
}
