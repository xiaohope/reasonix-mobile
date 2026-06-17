# Reasonix Mobile

<div align="center">

**手机端 AI 编程助手** — 基于 Flutter 构建，支持多模型、技能系统、终端执行

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Build APK](https://github.com/xiaohope/reasonix-mobile/actions/workflows/build-apk.yml/badge.svg)](https://github.com/xiaohope/reasonix-mobile/actions)

</div>

---

## 功能一览

| 模块 | 说明 |
|------|------|
| 💬 双模式对话 | 聊天模式（纯对话）/ 编程模式（带工具调用），独立会话管理 |
| 🧠 多技能系统 | 9 个内置技能，支持同时激活多个，注入 system prompt 生效 |
| 🔧 工具执行引擎 | 编程模式下 AI 可自动执行文件读写、终端命令、Git 操作等 10 种工具 |
| 🖼️ 多模态支持 | 支持图片上传，自动识别模型是否支持识图（Agnes/GPT-4/Claude/Gemini/通义千问VL） |
| 💻 内置终端 | 在手机上直接执行 Shell 命令，支持 git 操作 |
| 📁 文件浏览 | 浏览、编辑项目文件，支持代码高亮 |
| 🔑 多 Provider | 支持 DeepSeek、Agnes AI、OpenAI 等 OpenAI 兼容接口，随时切换 |
| 💾 会话管理 | 多会话持久化，支持导出 / 导入 |
| 🎨 深浅主题 | 内置 Catppuccin 风格配色，支持深浅色切换 |

---

## 截图

> 截图待补充

---

## 下载安装

### 方式一：GitHub Actions 构建（推荐）

1. 打开 [Actions 页面](https://github.com/xiaohope/reasonix-mobile/actions)
2. 选择最新的 **Build APK** 任务
3. 下载 Artifacts 中的 `reasonix-mobile-apk.zip`
4. 解压得到 `app-release.apk`，安装到手机

### 方式二：本地构建

```bash
# 克隆项目
git clone git@github.com:xiaohope/reasonix-mobile.git
cd reasonix-mobile

# 安装依赖
flutter pub get

# 构建 APK
flutter build apk --release

# 输出路径
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 快速上手

### 1. 配置 AI 模型

首次打开 App，进入 **设置 → 大模型 Provider**，填写：

- **API Base URL**：如 `https://api.deepseek.com/v1`
- **API Key**：你的 API Key
- **模型名**：如 `deepseek-chat`

内置支持快速填入 DeepSeek / Agnes AI 等常用 Provider。

### 2. 开始对话

- **聊天模式**：直接输入问题，AI 正常回复
- **编程模式**：先选择项目目录，AI 可调用工具操作文件和执行命令

### 3. 使用技能

点击输入框左侧的 🧠 按钮 → 选择技能（可多选）→ 技能注入后正常输入问题即可

当前内置技能：

| 图标 | 名称 | 说明 |
|------|------|------|
| 🔍 | 代码审查 | 审查项目代码，找出潜在问题 |
| 🐛 | 修复 Bug | 分析并修复代码 Bug |
| 📖 | 解释代码 | 用通俗语言解释代码逻辑 |
| ♻️ | 重构建议 | 提供代码重构方案 |
| 📝 | 添加注释 | 为代码补充清晰注释 |
| 🧪 | 编写测试 | 生成单元测试代码 |
| ⚡ | 性能优化 | 分析并优化代码性能 |
| 🔒 | 安全审查 | 检查代码中的安全隐患 |
| 👨🍼 | 超级奶爸 | 通用助手模式 |

### 4. 编程模式工具能力

在编程模式下，AI 可执行以下工具（最多 10 轮自动循环）：

- 📄 读取文件
- ✏️ 写入 / 修改文件
- 📂 列出目录
- 💻 执行终端命令
- 🔀 Git 操作（status / diff / commit 等）

---

## 项目结构

```
lib/
├── main.dart                      # 入口 + 底部导航
├── theme.dart                     # 深浅色主题（Catppuccin 风格）
│
├── models/                        # 数据模型
│   ├── message.dart               # 聊天消息（含多模态支持）
│   ├── tool_call.dart             # 工具调用记录
│   ├── file_node.dart             # 文件树节点
│   ├── project_config.dart        # 项目配置
│   ├── usage_info.dart            # Token 用量统计
│   ├── skill.dart                 # 技能（.skill.md 格式）
│   └── model_provider.dart        # 大模型 Provider 配置
│
├── providers/                     # 状态管理（Provider）
│   ├── chat_provider.dart         # 核心：对话循环 + 会话管理 + 技能注入
│   ├── settings_provider.dart     # 设置 + 多 Provider 存储
│   ├── project_provider.dart      # 项目目录管理
│   └── terminal_provider.dart    # 终端状态
│
├── services/                      # 服务层
│   ├── llm_service.dart           # LLM API 调用（OpenAI 兼容）
│   ├── tool_engine.dart           # 工具执行引擎
│   ├── file_service.dart          # 文件系统操作
│   ├── terminal_service.dart      # Shell 命令执行
│   ├── git_service.dart           # Git 操作
│   └── skill_service.dart        # 技能管理（.skill.md 文件）
│
├── pages/                         # 页面
│   ├── chat_page.dart             # 聊天页（主界面）
│   ├── sessions_page.dart         # 会话管理
│   ├── terminal_page.dart        # 终端
│   ├── files_page.dart            # 文件浏览
│   ├── settings_page.dart        # 设置页
│   ├── about_page.dart           # 关于
│   ├── skills_manage_page.dart   # 技能管理
│   └── providers_manage_page.dart # Provider 管理
│
└── widgets/                       # 可复用组件
    ├── chat_input.dart            # 输入框（图片/技能/发送）
    ├── message_bubble.dart        # 消息气泡（Markdown/图片/代码块）
    ├── file_tree.dart             # 文件树
    └── project_picker.dart        # 目录浏览器
```

---

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.x |
| 语言 | Dart 3.x |
| 状态管理 | Provider |
| 网络请求 | `http` |
| 持久化 | JSON 文件（本地） |
| 构建分发 | GitHub Actions |

---

## 已知问题

- 旧会话（v0.5.0 之前）没有 `mode` 字段，切换模式时会新建对话
- 费用计算基于 DeepSeek 旧价目表，可能与实际不符
- `chatStream`（流式）方法已实现但未在主流程使用
- 无单元测试

---

## 待优化

- [ ] Agnes Image 生图接口接入，支持 AI 生成图片直接显示
- [ ] 流式输出接入主对话流程
- [ ] Provider 多模态开关（手动配置）
- [ ] 视频显示支持

---

## 提交规范

```bash
git commit -m "type: 描述"
# 例：feat: 新增流式输出支持
```

类型：`feat` / `fix` / `refactor` / `docs` / `chore`

推送 `master` 分支自动触发 GitHub Actions 构建 APK。

---

## 版本记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v0.6.0 | 2026-06-18 | 重构技能系统（多技能持久激活）、修复输出截断（加 max_tokens）、移除知识库、助手消息支持 base64 图片 |
| v0.5.0 | 2026-06-11 | 多 Provider 支持、技能系统、知识库、会话导出导入 |

---

## License

MIT
