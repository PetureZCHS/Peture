package com.example.my_pet

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity : FlutterActivity() {

    // 用于与 Flutter 进行通信的频道
    private val CHANNEL = "nfc_channel"

    // 当应用启动时，配置 MethodChannel
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 配置 MethodChannel，处理从 Flutter 端的调用
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getNfcData") {
                // 获取从 NFC 标签传递过来的 URI 数据
                val uri = intent?.dataString
                result.success(uri)
            } else {
                result.notImplemented()
            }
        }
    }

    // 处理新打开的 Intent，当你刷 NFC 标签时，Android 会调用这个方法
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 更新 Activity 的 intent，使得你能够获取到 NFC 数据
        setIntent(intent)
    }
}
