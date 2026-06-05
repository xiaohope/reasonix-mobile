import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'pages/chat_page.dart';
import 'pages/terminal_page.dart';
import 'pages/settings_page.dart';
import 'pages/sessions_page.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/project_provider.dart';
import 'providers/terminal_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsProvider();
  await settings.load();
  final projectProvider = ProjectProvider();
  final chatProvider = ChatProvider();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: projectProvider),
        ChangeNotifierProvider.value(value: chatProvider..initProjectProvider(projectProvider)),
        ChangeNotifierProvider(create: (_) => TerminalProvider()),
      ],
      child: const ReasonixMobileApp(),
    ),
  );
}

class ReasonixMobileApp extends StatelessWidget {
  const ReasonixMobileApp({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'Reasonix',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          home: const AppShell(),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _switchToChat() {
    setState(() => _currentIndex = 0);
  }

  @override
  void initState() {
    super.initState();
    // 延迟到 build 之后设置回调，避免在 build 中读取 context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().onSwitchToChat = _switchToChat;
    });
  }

  final List<Widget> _pages = [
    const ChatPage(),
    const SessionsPage(),
    const TerminalPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: '聊天'),
          BottomNavigationBarItem(icon: Icon(Icons.history), activeIcon: Icon(Icons.history), label: '对话'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal_outlined), activeIcon: Icon(Icons.terminal), label: '终端'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
