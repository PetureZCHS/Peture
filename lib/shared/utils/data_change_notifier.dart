import 'package:flutter/material.dart';

/// 全局数据变更通知器，用于跨页面通知数据刷新需求。
class DataChangeNotifier {
  static bool petDataChanged = false;
  static final ValueNotifier<int> petDataRefreshNotifier =
      ValueNotifier<int>(0);

  /// 标记宠物数据已变更，需要刷新
  static void markPetDataChanged() {
    petDataChanged = true;
    petDataRefreshNotifier.value++;
  }

  /// 检查并重置标记
  static bool checkAndReset() {
    if (petDataChanged) {
      petDataChanged = false;
      return true;
    }
    return false;
  }
}
