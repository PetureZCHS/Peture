import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // 添加 intl 包
import 'package:flutter_localizations/flutter_localizations.dart'; // 添加本地化支持
import 'package:supabase_flutter/supabase_flutter.dart'; // 添加 Supabase
import 'package:sentry_flutter/sentry_flutter.dart'; // 添加 Sentry
import 'core/app_route_observer.dart';
import 'core/root_navigator_key.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/home/presentation/home_screen.dart';
import 'core/config/supabase_config.dart';
import 'services/analytics_service.dart';
import 'shared/design_system/peture_design_system.dart';

void main() async {
  // 确保 Flutter 框架初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Supabase（在 Sentry 之前，避免 Zone mismatch）
  debugPrint('开始初始化 Supabase...');
  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    anonKey: SupabaseConfig.anonKey,
    // 持久化会话并自动刷新 token，保证重开 App 后仍保持登录
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
    ),
  );
  debugPrint('Supabase 初始化成功');

  // 友盟 initCommon 若在 runApp 之前 await，原生启动屏会一直停到 SDK 返回（易卡死）
  unawaited(AnalyticsService.tryInitIfConsented());

  // 初始化 Sentry（捕获所有后续错误）
  await SentryFlutter.init(
    (options) {
      // 从环境变量读取 DSN（避免写死在代码里）
      options.dsn = const String.fromEnvironment(
        'SENTRY_DSN',
        defaultValue:
            'https://22a24ea50f240fc0ed9535537561e164@o4510786970845184.ingest.de.sentry.io/4510786972745808',
      );

      // 性能监控采样率：10% 的请求会采集性能数据（避免数据量过大）
      options.tracesSampleRate = 0.1;

      // 设置环境标识（开发/生产）
      options.environment =
          const String.fromEnvironment('ENV', defaultValue: 'development');

      // 设置 Release 版本（用于关联代码版本）
      options.release =
          const String.fromEnvironment('RELEASE', defaultValue: '1.0.0');
    },
    appRunner: () async {
      // 初始化日期格式化的本地化数据（中文）
      await initializeDateFormatting('zh_CN', null);

      // 启动根路由，根据登录状态自动切换
      runApp(const RootRouter());
    },
  );
}

/// 根路由：监听 Supabase Auth 状态，自动在登录页和主页之间切换。
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

    // 监听登录、登出和 Token 刷新事件
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      final event = authState.event;
      final session = authState.session;

      // 仅在明确签出/删号时清空会话，避免某些中间事件携带 null session 造成误回登录页。
      switch (event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
        case AuthChangeEvent.initialSession:
          setState(() {
            _session = session;
          });
          break;
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.userDeleted:
          setState(() {
            _session = null;
          });
          break;
        default:
          // 其他事件（如密码恢复）不主动改动当前路由态
          break;
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
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: '智宠合生',
      navigatorObservers: [appRouteObserver],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文简体
        Locale('en', 'US'), // 英文
      ],
      locale: const Locale('zh', 'CN'),
      home: _session != null ? const MyApp() : const LoginPage(),
    );
  }
}

/// 已登录后的主界面壳层：只能使用一个 [MaterialApp]（在 [RootRouter] 里）。
/// 此处只包 [Theme] + [Material]，避免嵌套第二个 [MaterialApp] 导致 Navigator GlobalKey 冲突。
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = PetureTheme.light();

    return Theme(
      data: theme,
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: const HomeScreen(),
      ),
    );
  }
}
