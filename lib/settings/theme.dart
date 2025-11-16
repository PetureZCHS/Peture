import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:settings_ui/settings_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 已删除：import 'theme_constants.dart'; - 不再需要主题颜色常量

class Themes extends StatefulWidget {
  const Themes({super.key});

  @override
  State<Themes> createState() => _ThemesState();
}

class _ThemesState extends State<Themes> {
  // 已删除：int _selectedThemeIndex = 0; - 不再需要主题索引

  // 当前主题模式
  AdaptiveThemeMode _themeMode = AdaptiveThemeMode.light;

  @override
  void initState() {
    super.initState();
    // 已删除：_loadCurrentThemeIndex(); - 不再需要加载主题索引
    _loadThemeMode();
  }

  // 已删除：_loadCurrentThemeIndex() 方法 - 不再需要加载主题索引
  // 已删除：_saveCurrentThemeIndex() 方法 - 不再需要保存主题索引

  // 加载主题模式
  _loadThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String themeModeString = prefs.getString('theme_mode') ?? 'light';
    setState(() {
      switch (themeModeString) {
        case 'light':
          _themeMode = AdaptiveThemeMode.light;
          break;
        case 'dark':
          _themeMode = AdaptiveThemeMode.dark;
          break;
        case 'system':
          _themeMode = AdaptiveThemeMode.system;
          break;
        default:
          _themeMode = AdaptiveThemeMode.light;
      }
    });
  }

  // 保存主题模式
  _saveThemeMode(AdaptiveThemeMode mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String modeString;
    switch (mode) {
      case AdaptiveThemeMode.light:
        modeString = 'light';
        break;
      case AdaptiveThemeMode.dark:
        modeString = 'dark';
        break;
      case AdaptiveThemeMode.system:
        modeString = 'system';
        break;
    }
    await prefs.setString('theme_mode', modeString);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('主题'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SettingsThemes(
        // 已删除：selectedThemeIndex 参数 - 不再需要传递主题索引
        themeMode: _themeMode,
        // 已删除：onThemeSelected 参数 - 不再需要主题选择回调
        onThemeModeChanged: (mode) async {
          setState(() {
            _themeMode = mode;
          });

          // 应用主题模式
          switch (mode) {
            case AdaptiveThemeMode.light:
              AdaptiveTheme.of(context).setLight();
              break;
            case AdaptiveThemeMode.dark:
              AdaptiveTheme.of(context).setDark();
              break;
            case AdaptiveThemeMode.system:
              AdaptiveTheme.of(context).setSystem();
              break;
          }

          // 保存主题模式
          await _saveThemeMode(mode);
        },
        // 已删除：themeColors 和 themeNames 参数 - 不再需要传递主题颜色数据
      ),
    );
  }
}

class SettingsThemes extends StatelessWidget {
  // 已删除：final int selectedThemeIndex; - 不再需要主题索引
  final AdaptiveThemeMode themeMode;
  // 已删除：final Function(int) onThemeSelected; - 不再需要主题选择回调
  final Function(AdaptiveThemeMode) onThemeModeChanged;
  // 已删除：final List<Color> themeColors; - 不再需要主题颜色列表
  // 已删除：final List<String> themeNames; - 不再需要主题名称列表

  const SettingsThemes({
    super.key,
    // 已删除：required this.selectedThemeIndex,
    required this.themeMode,
    // 已删除：required this.onThemeSelected,
    required this.onThemeModeChanged,
    // 已删除：required this.themeColors,
    // 已删除：required this.themeNames,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsList(
      sections: [
        // 已删除：整个"主题颜色"的 SettingsSection
        /*
        SettingsSection(
          title: Text('主题颜色'),
          tiles: List.generate(themeColors.length, (index) {
            return SettingsTile(
              leading: Container(
                width: 18,
                height: 18,
                color: themeColors[index],
              ),
              title: Text(themeNames[index]),
              trailing: selectedThemeIndex == index
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onPressed: (context) {
                onThemeSelected(index);
              },
            );
          }),
        ),
        */
        SettingsSection(
          title: Text('主题模式'),
          tiles: [
            SettingsTile(
              leading: Icon(Icons.light_mode),
              title: Text('浅色模式'),
              trailing: themeMode == AdaptiveThemeMode.light
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onPressed: (context) {
                onThemeModeChanged(AdaptiveThemeMode.light);
              },
            ),
            SettingsTile(
              leading: Icon(Icons.dark_mode),
              title: Text('深色模式'),
              trailing: themeMode == AdaptiveThemeMode.dark
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onPressed: (context) {
                onThemeModeChanged(AdaptiveThemeMode.dark);
              },
            ),
            SettingsTile(
              leading: Icon(Icons.phone_iphone_rounded),
              title: Text('跟随系统'),
              trailing: themeMode == AdaptiveThemeMode.system
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onPressed: (context) {
                onThemeModeChanged(AdaptiveThemeMode.system);
              },
            ),
          ],
        ),
      ],
    );
  }
}
