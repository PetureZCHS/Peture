import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_pet/core/config/supabase_config.dart';
import 'package:my_pet/shared/utils/data_change_notifier.dart';

// 直接导入要测试的页面
import 'package:my_pet/features/home/presentation/home_screen.dart';
import 'package:my_pet/features/dog_clicker/presentation/dog_clicker_screen.dart';
import 'package:my_pet/features/expense/presentation/unified_expense_home_page.dart';
import 'package:my_pet/features/pet_passport/presentation/pet_passport_page.dart';
import 'package:my_pet/features/diary/presentation/pet_diary_compose_page.dart';
import 'package:my_pet/features/image_generation/presentation/preparation_page.dart';
import 'package:my_pet/features/profile/presentation/account_settings_page.dart';

/// 冒烟测试：验证 5 个上架功能页面的导入和基础渲染。
void main() {
  test('DataChangeNotifier basic operations', () {
    expect(DataChangeNotifier.checkAndReset(), isFalse);
    DataChangeNotifier.markPetDataChanged();
    expect(DataChangeNotifier.checkAndReset(), isTrue);
    expect(DataChangeNotifier.checkAndReset(), isFalse);
  });

  group('Page construction (with Supabase)', () {
    setUpAll(() async {
      WidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await initializeDateFormatting('zh_CN', null);
      await Supabase.initialize(
        url: SupabaseConfig.projectUrl,
        anonKey: SupabaseConfig.anonKey,
      );
    });

    Future<void> pumpPage(WidgetTester tester, Widget page) async {
      await tester.pumpWidget(MaterialApp(home: page));
      // 允许异步初始化完成
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('HomeScreen renders without crash', (tester) async {
      await pumpPage(tester, const HomeScreen());
    });

    testWidgets('DogClickerScreen renders without crash', (tester) async {
      await pumpPage(tester, const DogClickerScreen());
    });

    testWidgets('UnifiedExpenseHomePage renders without crash',
        (tester) async {
      await pumpPage(tester, const UnifiedExpenseHomePage());
    });

    testWidgets('PetPassportPage renders without crash', (tester) async {
      await pumpPage(tester, const PetPassportPage());
    });

    testWidgets('PetDiaryComposePage renders without crash', (tester) async {
      await pumpPage(tester, const PetDiaryComposePage());
    });

    testWidgets('PreparationPage renders without crash', (tester) async {
      await pumpPage(tester, const PreparationPage());
    });

    testWidgets('AccountSettingsPage renders without crash', (tester) async {
      await pumpPage(tester, const AccountSettingsPage());
    });
  });
}
