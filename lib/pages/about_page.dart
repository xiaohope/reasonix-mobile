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
            child: Text('v0.5.0', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          const SizedBox(height: 24),
          _section('功能介绍', [
            '🤖 AI 编程助手，基于 DeepSeek 大模型 + Function Calling',
            '💬 双模式：聊天模式（纯聊） / 编程模式（读写项目文件）',
            '💬 多会话管理，每个对话独立绑定一个项目目录',
            '🧠 技能系统（Skills）：9 个内置技能 + 支持自定义导入',
            '   🔍 代码审查 · 🐛 修复Bug · 📖 解释代码',
            '   🛠️ 代码重构 · 💬 添加注释 · 🧪 写测试',
            '   ⚡ 性能优化 · 🔒 安全审查 · 🍼 超级奶爸',
            '📁 聊天页直接选择/切换项目目录',
            '🛠️ 工具调用：读文件、写文件、搜索代码、执行命令',
            '📊 实时 Token 用量统计 + 费用预估',
            '🖼️ 图片上传（支持识图）',
            '🌙 深色/浅色主题切换',
          ]),
          const SizedBox(height: 16),
          _section('使用方法', [
            '1. 在「设置」页配置 API Key（去 platform.deepseek.com 注册获取）',
            '2. 默认聊天模式：直接输入文字即可闲聊或提问',
            '3. 点击输入框上方的 [💻 编程] 切换到编程模式',
            '4. 编程模式需选择项目目录，AI 可以读写文件',
            '5. 点击输入框旁的 🧠 按钮使用技能模板',
            '6. 聊天模式只显示通用/自定义技能，编程模式显示全部',
            '7. 在「设置」→「技能管理」可自定义或导入 .skill.md',
            '8. 点击底部「对话」标签管理多个会话',
            '9. 点击底部「终端」标签执行 shell 命令（需安装 Termux）',
          ]),
          const SizedBox(height: 16),
          _section('模型说明', [
            '默认模型: deepseek-v4-flash（高性能编程模型）',
            '如需识图功能，请切换为 deepseek-chat',
            '可在「设置」页自由切换模型和 API 地址',
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
