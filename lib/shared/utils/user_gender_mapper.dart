/// 用户性别：界面文案与数据库枚举 `male` / `female` / `confidential`
class UserGenderMapper {
  UserGenderMapper._();

  static const List<String> dialogOptions = ['男', '女', '其他', '不透露'];

  static String? toDatabaseValue(String displayLabel) {
    switch (displayLabel) {
      case '男':
        return 'male';
      case '女':
        return 'female';
      case '其他':
        return 'other';
      case '不透露':
        return 'confidential';
      default:
        return null;
    }
  }

  /// 将数据库值转为列表/设置页展示文案
  static String toDisplayLabel(String? db) {
    if (db == null || db.isEmpty) return '未设置';
    switch (db) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      case 'other':
        return '其他';
      case 'confidential':
        return '不透露';
      default:
        return '未设置';
    }
  }
}
