# Reasonix Mobile — 项目交接文档

> 版本: v0.6.0 | Flutter 3.x | Dart 3.x
> 最后更新: 2026-06-11

---

## 一、项目概述

Reasonix Mobile 是一个手机端 AI 编程助手 App，支持多模型 Provider（DeepSeek / Agnes AI / OpenAI 等）、双模式（聊天/编程）、技能系统、知识库、多会话管理、文件读写等能力。

### 技术栈

| 项目 | 内容 |
|------|------|
| 框架 | Flutter 3.x |
| 语言 | Dart 3.x |
| 状态管理 | Provider + ChangeNotifier |
| 持久化 | JSON 文件（本地文件系统） |
| 网络请求 | `http` 包 |
| 图片选择 | `image_picker` |
| 构建 | GitHub Actions (build-apk.yml) |

---

## 二、项目结构

```
lib/
├── main.dart                      # 入口 + 底部导航
├── theme.dart                     # 深色/浅色主题
│
├── models/                        # 数据模型
│   ├── message.dart               # 聊天消息（含 imageBase64 多模态支持）
│   ├── tool_call.dart             # 工具调用
│   ├── file_node.dart             # 文件树节点
│   ├── project_config.dart        # 项目配置
│   ├── usage_info.dart            # Token 用量统计
│   ├── skill.dart                 # 技能（.skill.md 格式解析）
│   ├── knowledge.dart             # 知识库条目（.md 格式解析）
│   └── model_provider.dart        # 大模型 Provider 配置
│
├── providers/                     # 状态管理
│   ├── chat_provider.dart         # 核心：对话循环 + 会话管理 + 技能/知识注入
│   ├── settings_provider.dart     # 设置 + 多 Provider 存储
│   ├── project_provider.dart      # 项目目录管理
│   └── terminal_provider.dart     # 终端
│
├── services/                      # 服务层
│   ├── llm_service.dart           # LLM API 调用（OpenAI 兼容格式）
│   ├── tool_engine.dart           # 10 种工具执行引擎
│   ├── file_service.dart          # 文件系统操作
│   ├── terminal_service.dart      # Shell 命令执行
│   ├── git_service.dart           # Git 操作
│   ├── skill_service.dart         # 技能管理（单例、.skill.md 文件）
│   └── knowledge_service.dart     # 知识库管理（单例、.md 文件）
│
├── pages/                         # 页面
│   ├── chat_page.dart             # 聊天页（主界面）
│   ├── sessions_page.dart         # 对话管理
│   ├── terminal_page.dart         # 终端
│   ├── files_page.dart            # 文件浏览
│   ├── settings_page.dart         # 设置页
│   ├── about_page.dart            # 关于
│   ├── skills_manage_page.dart    # 技能管理
│   ├── knowledge_manage_page.dart # 知识库管理
│   └── providers_manage_page.dart # 大模型 Provider 管理
│
└── widgets/                       # 可复用组件
    ├── chat_input.dart            # 输入框（图片/技能/知识库/发送按钮）
    ├── message_bubble.dart        # 消息气泡（Markdown/图片/代码块）
    ├── file_tree.dart             # 文件树
    └── project_picker.dart        # 目录浏览器
```

---

## 三、核心功能详解

### 3.1 双模式（聊天/编程）

`lib/providers/chat_provider.dart` — `_isProgrammingMode`（默认 `false` = 聊天模式）

| 模式 | 需要项目 | 工具调用 | system prompt |
|------|:-------:|:--------:|:-------------:|
| 💬 聊天 | ❌ | ❌ | 无 |
| 💻 编程 | ✅ | ✅ | 包含项目路径 |

**切模式逻辑**（`setMode`）：
- 查找已有同模式对话（通过 `mode` 字段）
- 有 → 复用最近的同模式对话
- 无 → 新建对话，继承当前项目路径
- 新建对话时打上 `mode: 'chat'` 或 `mode: 'programming'` 标记

### 3.2 多会话管理

`lib/providers/chat_provider.dart`

- 每个会话独立 JSON 文件存储在 `reasonix/session_{id}.json`
- 会话元数据存储在 `reasonix/sessions.json`
- 每个会话绑定一个项目路径（`project_path` 字段）
- 支持导出（JSON / 文本）和导入

**会话数据结构**：
```json
{
  "version": 2,
  "last_updated": "...",
  "messages": [...],
  "usage": {
    "total_prompt_tokens": 0,
    "total_completion_tokens": 0,
    "total_cache_hit_tokens": 0,
    "total_cost": 0.0
  }
}
```

**会话元数据**：
```json
{
  "id": "123456789",
  "name": "编程 对话",
  "created_at": "...",
  "updated_at": "...",
  "project_path": "/storage/emulated/0/MyProject",
  "mode": "programming"
}
```

### 3.3 多 Provider 大模型管理

`lib/models/model_provider.dart` + `lib/pages/providers_manage_page.dart`

- 每个 Provider 独立配置：名称、API 地址、API Key、模型名
- 支持 DeepSeek、Agnes AI、OpenAI、通义千问等 OpenAI 兼容接口
- 设置页下拉切换 + 聊天页底部下拉切换
- 旧版单字段数据自动迁移到多 Provider 格式

**Provider 数据结构**：
```json
{
  "id": "deepseek",
  "name": "DeepSeek",
  "api_base_url": "https://api.deepseek.com/v1",
  "api_key": "sk-...",
  "model": "deepseek-v4-flash"
}
```

### 3.4 技能系统（Skills）

`lib/models/skill.dart` + `lib/services/skill_service.dart` + `lib/pages/skills_manage_page.dart`

- 技能以 `.skill.md` 文件存储在 `reasonix/skills/` 目录
- 9 个内置默认技能（代码审查、修复Bug、解释代码、重构、注释、测试、优化、安全审查、超级奶爸）
- 支持通过文件浏览器导入 `.skill.md` 文件
- 支持新建/编辑/删除/恢复默认

**.skill.md 文件格式**：
```markdown
---
name: 代码审查
description: 审查当前项目代码，找出问题
icon: 🔍
category: programming
prompt: 你现在是...（可选，有则发此短指令，无则发正文）
---

详细指令正文...
```

**技能执行流程**：
1. 用户点 🧠 → 选技能
2. 技能标记为 `_activeSkill`，显示 chip "🔍 技能名 已加载"
3. 用户输入指令
4. 技能 prompt 合并到用户消息前发送给 AI
5. AI 按技能上下文回复

**内置技能 ID 集合**（`SkillService.builtInSkillIds`）：
```dart
{'code_review', 'fix_bugs', 'explain', 'refactor',
 'add_comments', 'write_test', 'optimize', 'security', 'super-dad'}
```

### 3.5 知识库系统

`lib/models/knowledge.dart` + `lib/services/knowledge_service.dart` + `lib/pages/knowledge_manage_page.dart`

- 知识条目以 `.md` 文件存储在 `reasonix/knowledge/` 目录
- 支持导入 `.md` 文件（含 frontmatter）
- 支持新建/编辑/删除
- 聊天页 📚 按钮选择知识文档 → 以「请参考以下知识来回答：\n\n{内容}」形式发送

### 3.6 对话核心循环

`lib/providers/chat_provider.dart` — `sendMessage()`

**聊天模式**（无工具调用）：
```
用户输入 → 调用 API (includeTools=false) → 显示回复
```

**编程模式**（带工具调用）：
```
更新 system prompt → 调用 API (includeTools=true)
  → 有 tool_calls? → 执行工具 → 结果送回 API → 循环（最多10轮）
  → 无 tool_calls? → 显示回复
```

**多模态图片支持**（`toApiMessage(multimodal: bool)`）：
- 自动检测模型是否支持图片（Agnes、GPT-4、Gemini、Claude-3、通义千问VL）
- 支持 → 以 `image_url` 格式发送 base64 图片
- 不支持 → 只发文本，图片仅本地显示

### 3.7 LlmService 关键参数

`lib/services/llm_service.dart`

- `chatComplete(messages, {includeTools = true})` — 非流式调用
- `chatStream(messages)` — 流式调用（当前未在主流程使用）
- `checkBalance()` — 查询余额
- 自动多模态检测（基于模型名关键词）

---

## 四、关键数据流

### 启动流程
```
main.dart
  → SettingsProvider.load()          ← 加载设置 + Provider 列表
  → ProjectProvider()                ← 空项目
  → ChatProvider.init()              ← 加载会话 + 恢复项目路径
    → _loadSessionMeta()             ← 读取 sessions.json
    → _migrateOldFormat()            ← 旧数据迁移
    → _loadSessionMessages()         ← 读取当前会话消息
    → 恢复 project_path              ← 打开上次绑定的项目
```

### 发送消息流程
```
ChatInput._send()
  → ChatPage._sendMessage(text)
    → ChatProvider.sendMessage(text)
      → 聊天模式: LlmService.chatComplete(messages, includeTools: false)
      → 编程模式: _updateSystemPrompt() → 工具循环（最多10轮）
```

### 模型切换流程
```
聊天页下拉 onChanged
  → SettingsProvider.selectProvider(id)
  → LlmService.configure(apiKey, baseUrl, model)
```

---

## 五、持久化文件结构

App 数据目录 (`getApplicationDocumentsDirectory()/reasonix/`):
```
reasonix/
├── reasonix_settings.json    # 设置（Provider 列表 + 主题 + 最后项目路径）
├── sessions.json             # 会话元数据列表
├── session_{id}.json         # 每个会话的消息
├── skills/                   # 技能文件
│   ├── code_review.skill.md
│   ├── fix_bugs.skill.md
│   └── ...
└── knowledge/                # 知识库文件
    ├── flutter_guide.md
    └── ...
```

---

## 六、当前状态

### 已完成功能
- [x] 双模式（聊天/编程）
- [x] 多会话管理（持久化 + 导出/导入）
- [x] 多 Provider 大模型管理
- [x] 技能系统（9 内置 + 自定义导入）
- [x] 知识库系统
- [x] 文件浏览/编辑
- [x] 终端命令执行
- [x] 项目目录选择（聊天页直接选）
- [x] 消息图片渲染（网络图片 + 本地上传）
- [x] 多模态 API 支持（识图）
- [x] Token 用量统计 + 费用预估
- [x] 深色/浅色主题

### 已知边缘情况
1. **会话 mode 标记**：旧会话（0.5.0 之前）没有 `mode` 字段，切模式时可能找不到对应对话，会新建
2. **费用计算硬编码**：`chat_provider.dart` 中的费用计算基于 DeepSeek 旧价目表
3. **流式方法未使用**：`chatStream` 方法已实现但未被主流程调用
4. **无单元测试**：`test/` 目录只有默认模板
5. **终端无历史记录**：每次清屏后丢失之前的命令输出

### 待优化
- Agnes Image 专用生图接口接入
- 自动关键词匹配知识库
- Provider 支持多模态开关（手动配置）
- 视频显示支持（需 `video_player` 包）

---

## 七、构建方式

### GitHub Actions（自动）
推送 `master` 分支后，`.github/workflows/build-apk.yml` 自动构建：
```
Actions → Build APK → Artifacts → reasonix-mobile-apk.zip
```

### 本地构建
```bash
flutter pub get
flutter build apk --release
# APK → build/app/outputs/flutter-apk/app-release.apk
```

### 提交规范
```bash
git add -A
git commit -m "type: 描述"
git push origin master
# HTTPS 不通时用 SSH
```

---

## 八、新智能体接入指引

推荐阅读顺序：
1. 先看 `lib/main.dart` — 入口和导航
2. 看 `lib/providers/chat_provider.dart` — 核心逻辑
3. 看 `lib/services/llm_service.dart` — API 调用
4. 看 `lib/pages/chat_page.dart` — UI 主界面
5. 按需看 `settings_page.dart` / `skills_manage_page.dart` 等

### 常见开发模式

**新增功能** → 先 mock 确认再开发，开发完后通知用户确认再推送

**修改 Provider** → 改 `settings_provider.dart` + 前端页面
**修改 AI 调用** → 改 `llm_service.dart` + `chat_provider.dart`
**新增页面** → 创建 `lib/pages/xxx_page.dart` + 注册导航
**新增持久化** → JSON 文件 + `path_provider`
