import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:intl/date_symbol_data_local.dart'; // 添加 intl 包
import 'package:flutter_localizations/flutter_localizations.dart'; // 添加本地化支持
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ 添加 Supabase
import 'login_page.dart'; // <-- 这是新添加的导入
import 'home_screen.dart';
import 'settings/theme_constants.dart';




void main() async {
  // 确保 Flutter 框架初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日期格式化的本地化数据 (中文)
  await initializeDateFormatting('zh_CN', null);

  // ✅ 初始化 Supabase
  print('🔧 开始初始化 Supabase...');
  await Supabase.initialize(
    url: 'https://tcftpcvcldfudzxgemdh.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRjZnRwY3ZjbGRmdWR6eGdlbWRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2NjMzMTQsImV4cCI6MjA3NjIzOTMxNH0.uiusEWfuAw37fL6neZfK3q9NV4HZF7k-kX6hFIJQ83s',
  );
  print('✅ Supabase 初始化成功');

  // 将您的登录页面包裹在一个 MaterialApp 中
  runApp(
    MaterialApp(
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
      home: const LoginPage(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final int currentThemeIndex;
  final AdaptiveThemeMode initialThemeMode;

  const MyApp({
    super.key,
    this.currentThemeIndex = 0,
    this.initialThemeMode = AdaptiveThemeMode.light,
  });

  @override
  Widget build(BuildContext context) {
    double appBarTextFontSize = 20;
    return AdaptiveTheme(
      // --- 修改开始: 更新为新的浅色主题 ---
      light: ThemeData(
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
      // --- 修改结束 ---
      dark: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: ThemeConstants.themeColors[currentThemeIndex],
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(fontSize: appBarTextFontSize),
        ),
      ),
      initial: initialThemeMode,
      // debugShowFloatingThemeButton: true,
      builder: (theme, darkTheme) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '智宠合生',
        theme: theme,
        darkTheme: darkTheme,
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
      ),
    );
  }
}
