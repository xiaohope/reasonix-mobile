# Reasonix Mobile

<p align="center">
  <b>把 AI 编程助手装进口袋</b><br/>
  不是又一个聊天 App——是能在手机上真干活儿的 AI 编程终端
</p>

<p align="center">
  <a href="https://github.com/xiaohope/reasonix-mobile/actions/workflows/build-apk.yml">
    <img src="https://github.com/xiaohope/reasonix-mobile/actions/workflows/build-apk.yml/badge.svg" alt="Build APK"/>
  </a>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-2ecc71" alt="Platform"/>
</p>

---

## 它和其他 AI 助手有什么不同？

| | 普通 AI 助手 | **Reasonix Mobile** |
|--|-------------|---------------------|
| 能写代码？ | ✅ 只能给建议 | ✅ **直接改你项目里的文件** |
| 能执行命令？ | ❌ 纯聊天 | ✅ **内置终端，手机上跑 git/build** |
| 需要电脑？ | 部分功能受限 | ✅ **专为手机设计，随时随地** |
| 模型锁定？ |  often | ✅ **随便换，DeepSeek/Agnes/OpenAI 都行** |
| 技能系统？ | 无或简陋 | ✅ **多技能同时激活，注入 system prompt** |

---

## 核心能力

### 💻 编程模式 — AI 不只是说，它能做

切换到编程模式后，AI 获得「手」：

```
你：「帮我修复登录页面的 Bug」
AI：自动读取文件 → 分析 → 修改代码 → git diff → 等你确认
```

内置 **10 种工具**，AI 可自动调用：

```
📄 读取文件          📝 写入/修改文件
📂 列出目录          💻 执行终端命令
🔀 Git 操作           🔍 搜索代码
📋 列表会话           🛠️ 项目管理
🔧 工具调用           📊 用量统计
```

> 最多 10 轮自动循环，AI 自己决定下一步用什么工具，不需要你手动操作。

---

### 🧠 技能系统 — 把专家指令装进对话

不是「选一个技能用一次」——而是 **同时激活多个技能，每轮对话都生效**。

```
点击 🧠 → 勾选「代码审查」+「安全审查」+「性能优化」
         → 正常提问
         → AI 同时从三个维度给你建议
```

内置 9 个技能，覆盖完整开发流程：

```
🔍 代码审查    🐛 修复 Bug    📖 解释代码
♻️ 重构建议    📝 添加注释    🧪 编写测试
⚡ 性能优化    🔒 安全审查    👨🍼 超级奶爸
```

支持导入自定义 `.skill.md` 文件，打造你自己的 AI 工作流。

---

### 📱 专为移动端设计

不是在网页上套个 WebView——是原生 Flutter App，针对手机操作做了完整优化：

- **底部导航**：聊天 / 会话 / 终端 / 设置，单手可切换
- **文件浏览**：在手机上直接看项目文件树，点开即编辑
- **内置终端**：`git status`、`flutter build`、`ls -la`……手机上直接跑
- **图片识图**：拍照上传，AI 直接看截图帮你 Debug

---

### 🔌 不绑定任何模型

你的 API Key，你说了算：

```
DeepSeek          Agnes AI
OpenAI           Claude（通过 OpenAI 兼容接口）
通义千问         本地 OAI模型
……随便换
```

切换 Provider 不需要重启 App，下拉选一下就行。

---

## 安装

### 最新构建（推荐）

前往 [Releases](https://github.com/xiaohope/reasonix-mobile/releases) 或 [Actions](https://github.com/xiaohope/reasonix-mobile/actions) 下载最新 APK。

### 自己构建

```bash
git clone https://github.com/xiaohope/reasonix-mobile.git
cd reasonix-mobile
flutter pub get
flutter build apk --release
# 输出：build/app/outputs/flutter-apk/app-release.apk
```

---

## 快速开始

**第一步：配置模型**
> 设置 → 大模型 Provider → 填入你的 API Key

**第二步：开始对话**
> 聊天模式直接问；编程模式先选项目目录

**第三步：激活技能（可选）**
> 点 🧠 → 选技能 → 正常提问，AI 自动带技能上下文

---

## 项目结构

```
reasonix_mobile/
├── lib/
│   ├── main.dart               # 入口
│   ├── theme.dart              # Catppuccin 主题
│   ├── models/                 # 数据模型（消息/技能/工具调用/Provider）
│   ├── providers/              # 状态管理（对话/设置/项目/终端）
│   ├── services/               # 业务层（LLM/工具引擎/文件/终端/Git）
│   ├── pages/                  # 页面（聊天/终端/设置/技能管理）
│   └── widgets/               # 组件（消息气泡/文件树/输入框）
├── android/ ios/ web/          # 多平台支持
└── .github/workflows/          # 自动构建 APK
```

---

## 技术栈

```
Flutter 3.x  +  Dart 3.x
Provider（状态管理）
http（网络请求）
JSON 文件持久化（无数据库依赖）
GitHub Actions（自动构建）
```

---

## 路线图

- [ ] 流式输出接入主对话（当前已实现但未启用）
- [ ] Agnes Image 生图接口，AI 生成图片直接显示
- [ ] iOS 版本上架
- [ ] 技能市场（一键导入社区技能）
- [ ] 离线模式（本地 OAI模型 支持）

---

## 贡献

Fork → 改代码 → Push → PR，欢迎任何形式的贡献。

提交规范：`type: 描述`（feat / fix / refactor / docs / chore）

---

## License

MIT — 随便用，随便改。

---

<div align="center">
  <b>Reasonix Mobile</b> — 让手机成为你的移动编程工作站 🚀
</div>
