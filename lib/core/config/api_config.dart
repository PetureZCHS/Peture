/// API 配置文件
///
/// 此文件集中管理所有API端点的配置，便于环境切换和维护。
library;

class ApiConfig {
  // ========== 基础配置 ==========

  /// 后端服务器基础URL
  ///
  /// 开发环境配置说明：
  /// - 真机/模拟器调试：使用开发电脑的局域网IP地址
  /// - 本地调试（仅适用于Web）：可使用 localhost 或 127.0.0.1
  ///
  /// 生产环境：替换为实际的生产服务器地址
  static const String baseUrl = 'http://172.20.10.3:3000';

  // ========== 认证相关API ==========

  /// 用户注册端点
  static String get registerUrl => '$baseUrl/api/auth/register';

  /// 用户登录端点（邮箱+密码）
  static String get loginUrl => '$baseUrl/api/auth/login';

  /// 邮箱验证端点
  static String get verifyEmailUrl => '$baseUrl/api/auth/verify-email';

  /// 发送验证码端点
  static String get sendVerificationCodeUrl => '$baseUrl/api/auth/send-code';

  /// 验证码登录端点
  static String get verifyCodeLoginUrl => '$baseUrl/api/auth/verify-code-login';

  // ========== 聊天相关API ==========

  /// 聊天流式API端点
  /// 注意：如果使用第三方服务，请直接返回完整URL
  static String get chatStreamUrl =>
      'https://newotgqgblas.sealoshzh.site/api/chat/stream'; // 第三方AI服务
  // '$baseUrl/api/chat/stream'; // 自建服务（取消注释以使用）

  /// 聊天历史端点
  static String get chatHistoryUrl => '$baseUrl/api/chat/history';

  // ========== 用户相关API ==========

  /// 用户信息端点
  static String get userInfoUrl => '$baseUrl/api/user/info';

  /// 更新用户信息端点
  static String get updateUserUrl => '$baseUrl/api/user/update';

  // ========== 宠物相关API ==========

  /// 宠物列表端点
  static String get petListUrl => '$baseUrl/api/pet/list';

  /// 添加宠物端点
  static String get addPetUrl => '$baseUrl/api/pet/add';

  // ========== 工具方法 ==========

  /// 构建完整的API URL
  ///
  /// @param endpoint API端点路径（如：'/api/user/profile'）
  /// @return 完整的URL
  static String buildUrl(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return endpoint;
    }

    // 确保endpoint以'/'开头
    if (!endpoint.startsWith('/')) {
      endpoint = '/$endpoint';
    }

    return '$baseUrl$endpoint';
  }

  /// 检查是否为开发环境
  static bool get isDevelopment => baseUrl.contains('172.20.10.3');

  /// 检查是否为生产环境
  static bool get isProduction => !isDevelopment;
}

/// 环境配置快速切换
///
/// 使用方法：
/// 1. 修改 ApiConfig.baseUrl 的值
/// 2. 或者在此处定义多个环境，通过切换注释来使用
class Environment {
  /// 本地开发环境（需要使用局域网IP）
  static const String local = 'http://172.20.10.3:3000';

  /// 测试环境
  static const String staging = 'https://staging-api.example.com';

  /// 生产环境
  static const String production = 'https://api.example.com';

  /// 当前使用的环境
  /// 修改此值来切换环境
  static const String current = local;
}
