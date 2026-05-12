import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 用于无服务端 id 时的内容指纹（如未保存日记、聊天消息）
String contentDigestSha256(String text) {
  final bytes = utf8.encode(text);
  return sha256.convert(bytes).toString();
}
