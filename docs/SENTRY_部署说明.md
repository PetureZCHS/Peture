# Sentry 错误监控部署说明

本应用已集成 Sentry Flutter SDK，用于捕获崩溃与异常并上报到 Sentry 后台。

## 1. 依赖与初始化

- **依赖**：`pubspec.yaml` 中已添加 `sentry_flutter: ^8.0.0`
- **初始化**：在 `lib/main.dart` 中，`main()` 内最先调用 `SentryFlutter.init()`，确保后续所有错误可被捕获

## 2. 配置项说明

当前在 `main.dart` 中使用的配置：

| 配置 | 说明 | 默认值 |
|------|------|--------|
| **DSN** | Sentry 项目接入地址，从环境变量 `SENTRY_DSN` 读取 | 代码内 `defaultValue` 为当前项目 DSN |
| **tracesSampleRate** | 性能监控采样率（0~1） | 0.1（10%） |
| **environment** | 环境标识（开发/生产） | 从 `ENV` 读取，默认 `development` |
| **release** | 版本号，用于关联错误与发布 | 从 `RELEASE` 读取，默认 `1.0.0` |

## 3. 生产环境建议

- **DSN**：建议通过 CI/本地构建时传入 `--dart-define=SENTRY_DSN=你的DSN`，避免把生产 DSN 写死在仓库
- **release**：打包时传入真实版本号，例如  
  `--dart-define=RELEASE=1.2.0`  
  便于在 Sentry 中按版本筛选问题
- **environment**：区分环境，例如  
  `--dart-define=ENV=production`

## 4. 打包示例（带 Sentry 参数）

```bash
# 示例：Release 包并指定 Sentry 与版本
flutter build apk --dart-define=ENV=production --dart-define=RELEASE=1.0.0 --dart-define=SENTRY_DSN=你的DSN
```

iOS 同理，使用 `flutter build ios` 并加上相同 `--dart-define`。

## 5. Sentry 后台

- 登录 [sentry.io](https://sentry.io) 进入对应项目
- 在 **Issues** 查看崩溃与异常
- 在 **Releases** 关联版本与 source map（若已配置上传），便于定位堆栈

## 6. 注意事项

- 未设置 `SENTRY_DSN` 时使用代码中的 `defaultValue`，仅适合开发/测试
- 生产环境务必使用自己的 DSN，并避免将敏感 DSN 提交到公开仓库
