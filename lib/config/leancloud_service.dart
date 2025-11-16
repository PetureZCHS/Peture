import 'dart:convert';
import 'package:http/http.dart' as http;
import 'leancloud_config.dart';

/// LeanCloud 服务类，处理手机号验证码相关 API 调用
class LeanCloudService {
  /// 请求短信验证码
  ///
  /// [mobilePhoneNumber] 手机号
  /// 返回 true 表示成功，false 表示失败
  static Future<bool> requestSmsCode(String mobilePhoneNumber) async {
    // 测试号直接返回成功，不实际调用 API
    if (mobilePhoneNumber == '18639529172') {
      print('测试号 $mobilePhoneNumber，跳过实际发送验证码');
      return true;
    }

    final url = Uri.parse('${LeanCloudConfig.serverUrl}/1.1/requestSmsCode');

    try {
      final response = await http.post(
        url,
        headers: {
          'X-LC-Id': LeanCloudConfig.appId,
          'X-LC-Key': LeanCloudConfig.appKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'mobilePhoneNumber': mobilePhoneNumber}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('请求验证码失败: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('请求验证码异常: $e');
      return false;
    }
  }

  /// 验证短信验证码并登录
  ///
  /// [mobilePhoneNumber] 手机号
  /// [smsCode] 验证码
  /// 返回用户信息 Map，失败返回 null
  static Future<Map<String, dynamic>?> verifyAndLogin(
    String mobilePhoneNumber,
    String smsCode,
  ) async {
    // 测试号模拟登录（验证码为 746018）
    if (mobilePhoneNumber == '18639529172' && smsCode == '746018') {
      print('测试号登录成功');
      return {
        'objectId': 'test_user_id_${DateTime.now().millisecondsSinceEpoch}',
        'sessionToken':
            'test_session_token_${DateTime.now().millisecondsSinceEpoch}',
        'mobilePhoneNumber': mobilePhoneNumber,
        'username': mobilePhoneNumber,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
    }

    final url = Uri.parse(
      '${LeanCloudConfig.serverUrl}/1.1/usersByMobilePhone',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'X-LC-Id': LeanCloudConfig.appId,
          'X-LC-Key': LeanCloudConfig.appKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'mobilePhoneNumber': mobilePhoneNumber,
          'smsCode': smsCode,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        print('验证码登录失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('验证码登录异常: $e');
      return null;
    }
  }

  /// 获取当前登录的用户信息
  ///
  /// [sessionToken] 会话令牌
  /// 返回用户信息 Map，失败返回 null
  static Future<Map<String, dynamic>?> getCurrentUser(
    String sessionToken,
  ) async {
    final url = Uri.parse('${LeanCloudConfig.serverUrl}/1.1/users/me');

    try {
      final response = await http.get(
        url,
        headers: {
          'X-LC-Id': LeanCloudConfig.appId,
          'X-LC-Key': LeanCloudConfig.appKey,
          'X-LC-Session': sessionToken,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        print('获取用户信息失败: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('获取用户信息异常: $e');
      return null;
    }
  }
}
