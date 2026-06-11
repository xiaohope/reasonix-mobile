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
            child: Text('v0.6.0', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
          const SizedBox(height: 24),
          _section('功能介绍', [
            '🤖 AI 编程助手，基于大模型 + Function Calling',
            '🏗️ 多 Provider 支持：DeepSeek / OpenAI / 通义千问等',
            '💬 双模式：聊天模式（纯聊） / 编程模式（读写项目文件）',
            '📚 知识库系统：上传 .md 文档供 AI 参考回答',
            '🧠 技能系统：9 个内置技能 + 支持自定义导入 .skill.md',
            '   🔍 代码审查 · 🐛 修复Bug · 📖 解释代码',
            '   🛠️ 代码重构 · 💬 添加注释 · 🧪 写测试',
            '   ⚡ 性能优化 · 🔒 安全审查 · 🍼 超级奶爸',
            '💬 多会话管理，每个对话独立绑定项目和模式',
            '📁 聊天页直接选择/切换项目目录',
            '🛠️ 工具调用：读文件、写文件、搜索代码、执行命令',
            '📊 实时 Token 用量统计 + 费用预估',
            '🖼️ 图片上传（支持识图）',
            '🌙 深色/浅色主题切换',
          ]),
          const SizedBox(height: 16),
          _section('使用方法', [
            '1. 在「设置」→「大模型」配置 API Key（去对应平台注册）',
            '2. 默认聊天模式：直接输入文字即可闲聊或提问',
            '3. 支持多 Provider 切换，设置页可添加/编辑/删除',
            '4. 点击输入框上方的 [💻 编程] 切换到编程模式',
            '5. 编程模式需选择项目目录，AI 可以读写文件',
            '6. 切换模式自动切换回上次的同模式对话，不重复新建',
            '7. 点击 📚 从知识库选择参考文档，AI 据此回答',
            '8. 点击 🧠 使用技能模板，快速审查/重构/修复代码',
            '9. 在「设置」→「技能管理」可自定义或导入 .skill.md',
            '10. 在「设置」→「知识库」可上传 .md 参考文档',
            '11. 点击底部「对话」标签管理多个会话',
            '12. 点击底部「终端」标签执行 shell 命令（需 Termux）',
          ]),
          const SizedBox(height: 16),
          _section('模型说明', [
            '支持多个大模型 Provider，在设置页管理',
            '默认: DeepSeek deepseek-v4-flash（高性能编程模型）',
            '可添加 OpenAI、通义千问等兼容 OpenAI API 的服务',
            '每个 Provider 独立存储 API Key 和模型配置',
          ]),
          const SizedBox(height: 16),
          _section('权限说明', [
            '文件读写权限：用于浏览和修改项目代码',
            '网络权限：访问大模型 API',
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
