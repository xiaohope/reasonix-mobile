import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于 Reasonix')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: Icon(Icons.auto_awesome, size: 64, color: Color(0xFF6C63FF)),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Reasonix Mobile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const Center(
            child: Text('v0.3.0', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          const SizedBox(height: 24),
          _section('功能介绍', [
            '🤖 AI 编程助手，基于 DeepSeek 大模型',
            '📁 浏览和管理手机上的项目文件',
            '💬 多会话管理，聊天记录本地持久化',
            '🛠️ 支持工具调用：读文件、写文件、搜索代码、执行命令',
            '📊 实时 Token 用量统计',
            '🌙 深色/浅色主题切换',
          ]),
          const SizedBox(height: 16),
          _section('使用方法', [
            '1. 在「设置」页配置 API Key（去 platform.deepseek.com 注册获取）',
            '2. 在「设置」页选择项目目录（浏览或手动输入路径）',
            '3. 点击底部「聊天」标签，输入指令开始对话',
            '4. 点击底部「对话」标签管理多个会话',
            '5. 点击底部「终端」标签执行 shell 命令（需安装 Termux）',
          ]),
          const SizedBox(height: 16),
          _section('模型说明', [
            '默认使用 deepseek-v4-flash（高性能编程模型）',
            '如需识图功能，请切换为 deepseek-chat',
            'API 地址: https://api.deepseek.com/v1',
          ]),
          const SizedBox(height: 16),
          _section('权限说明', [
            '文件读写权限：用于浏览和修改项目代码',
            '网络权限：访问 DeepSeek API',
            'Android 11+ 需要手动授予「所有文件访问权限」',
          ]),
          const SizedBox(height: 24),
          const Center(
            child: Text('Made with ❤️ by Reasonix + AI', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(item, style: const TextStyle(fontSize: 14)),
            )),
          ],
        ),
      ),
    );
  }
}
