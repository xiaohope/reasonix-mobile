/// AI 大模型提供商配置
class ModelProvider {
  final String id;
  String name;            /// 显示名称，如 "DeepSeek"
  String apiBaseUrl;      /// API 地址
  String apiKey;          /// API Key
  String model;           /// 模型名，如 "deepseek-v4-flash"

  ModelProvider({
    required this.id,
    required this.name,
    required this.apiBaseUrl,
    required this.apiKey,
    required this.model,
  });

  bool get isConfigured => apiKey.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'api_base_url': apiBaseUrl,
    'api_key': apiKey,
    'model': model,
  };

  factory ModelProvider.fromJson(Map<String, dynamic> json) => ModelProvider(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    apiBaseUrl: json['api_base_url'] as String? ?? 'https://api.deepseek.com/v1',
    apiKey: json['api_key'] as String? ?? '',
    model: json['model'] as String? ?? 'deepseek-v4-flash',
  );

  ModelProvider copy() => ModelProvider(
    id: id, name: name, apiBaseUrl: apiBaseUrl,
    apiKey: apiKey, model: model,
  );
}
