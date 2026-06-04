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

  /// 缓存命中率
  double get cacheHitRate {
    if (promptTokens == 0) return 0;
    return (promptCacheHitTokens ?? 0) / promptTokens;
  }

  /// 估算费用（元）
  double get estimatedCost {
    final input = (promptTokens - (promptCacheHitTokens ?? 0)).clamp(0, promptTokens) * 0.000001;
    final output = completionTokens * 0.000002;
    final cached = (promptCacheHitTokens ?? 0) * 0.0000005; // 缓存命中半价
    return input + output + cached;
  }

  String get summary {
    final parts = <String>[
      '⇧${_fmt(promptTokens)}',
      '⇩${_fmt(completionTokens)}',
      '∑${_fmt(totalTokens)}',
    ];
    if (promptCacheHitTokens != null && promptCacheHitTokens! > 0) {
      parts.add('📦${_fmt(promptCacheHitTokens!)}');
      parts.add('${(cacheHitRate * 100).toStringAsFixed(0)}%');
    }
    parts.add('¥${estimatedCost.toStringAsFixed(4)}');
    return parts.join(' · ');
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
