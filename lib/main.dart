import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // 添加 intl 包
import 'package:flutter_localizations/flutter_localizations.dart'; // 添加本地化支持
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ 添加 Supabase
import 'package:sentry_flutter/sentry_flutter.dart'; // ✅ 添加 Sentry
import 'login_page.dart'; // <-- 这是新添加的导入
import 'home_screen.dart';




void main() async {
  // 确保 Flutter 框架初始化
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 初始化 Sentry（最早初始化，捕获所有后续错误）
  await SentryFlutter.init(
    (options) {
      // 从环境变量读取 DSN（避免写死在代码里）
      options.dsn = const String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue: 'https://22a24ea50f240fc0ed9535537561e164@o4510786970845184.ingest.de.sentry.io/4510786972745808',
      );
      
      // 性能监控采样率：10% 的请求会采集性能数据（避免数据量过大）
      options.tracesSampleRate = 0.1;
      
      // 设置环境标识（开发/生产）
      options.environment = const String.fromEnvironment('ENV', defaultValue: 'development');
      
      // 设置 Release 版本（用于关联代码版本）
      options.release = const String.fromEnvironment('RELEASE', defaultValue: '1.0.0');
    },
    appRunner: () async {
      // 初始化日期格式化的本地化数据 (中文)
      await initializeDateFormatting('zh_CN', null);

      // ✅ 初始化 Supabase（在 Sentry 之后，这样 Supabase 的错误也能被捕获）
      print('🔧 开始初始化 Supabase...');
      await Supabase.initialize(
        url: 'https://tcftpcvcldfudzxgemdh.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjZnRwY3ZjbGRmdWR6eGdlbWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NjMzMTQsImV4cCI6MjA3NjIzOTMxNH0.uiusEWfuAw37fL6neZfK3q9NV4HZF7k-kX6hFIJQ83s',
        // 持久化会话并自动刷新 token，保证重开 App 后仍保持登录
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: true,
        ),
      );
      print('✅ Supabase 初始化成功');

      // 启动根路由，根据登录状态自动切换
      runApp(const RootRouter());
    },
  );
}

/// 根路由：监听 Supabase Auth 状态，自动在登录页和主页之间切换
class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  Session? _session;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // 读取本地已持久化的会话
    _session = Supabase.instance.client.auth.currentSession;

    // 监听登录/登出/Token 刷新事件
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      final event = authState.event;
      final session = authState.session;

      // token 刷新失败、签出、用户删除等都会触发 session 为空，此时回到登录页
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        setState(() {
          _session = session;
        });
      } else if (event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.userDeleted ||
          session == null) {
        setState(() {
          _session = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文简体
        Locale('en', 'US'), // 英文
      ],
      home: _session != null ? const MyApp() : const LoginPage(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    double appBarTextFontSize = 20;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '智宠合生',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F7F7), // 浅灰色背景
        primaryColor: const Color(0xFF007AFF), // 主题蓝色
        fontFamily: '.SF Pro Text',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007AFF), // 主要颜色 (按钮、高亮)
          secondary: Color(0xFF5856D6), // 次要颜色
          surface: Colors.white, // 卡片背景色
          onSurface: Colors.black87, // 卡片上的文字颜色
        ),
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: appBarTextFontSize,
            color: Colors.black87, // 浅色模式下标题为黑色
          ),
          iconTheme: const IconThemeData(color: Colors.black87), // 浅色模式下图标为黑色
          backgroundColor: Colors.transparent, // 透明 AppBar 背景
          elevation: 0,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF007AFF), // TextButton 默认文字颜色
          ),
        ),
      ),
      // 添加本地化支持
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文简体
        Locale('en', 'US'), // 英文
      ],
      locale: const Locale('zh', 'CN'), // 默认使用中文

      home: const HomeScreen(),
    );
  }
}
