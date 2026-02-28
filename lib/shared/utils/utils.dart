import 'dart:math';

// 随机字符串函数
String generateRandomString() {
  final rnd = Random.secure();
  final length = 8 + rnd.nextInt(5); // 生成 8 到 12 位之间的随机长度
  const chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';

  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ),
  );
}
