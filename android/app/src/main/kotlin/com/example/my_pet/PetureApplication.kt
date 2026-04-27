package com.example.my_pet

import android.app.Application
import com.umeng.commonsdk.UMConfigure

/**
 * 友盟合规：Application.onCreate 中仅 preInit（不采集设备信息）。
 * 正式采集在用户同意隐私政策后，由 Flutter 调用 UmengCommonSdk.initCommon。
 *
 * 使用 [Application] 而非 FlutterApplication：当前 Flutter/Gradle 依赖下
 * io.flutter.embedding.android.FlutterApplication 可能无法解析，且 preInit 仅需 Context。
 */
class PetureApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        UMConfigure.preInit(this, UMENG_ANDROID_APP_KEY, UMENG_CHANNEL)
    }

    private companion object {
        const val UMENG_ANDROID_APP_KEY = "69da1f829a7f376488bdeb2d"
        const val UMENG_CHANNEL = "official"
    }
}
