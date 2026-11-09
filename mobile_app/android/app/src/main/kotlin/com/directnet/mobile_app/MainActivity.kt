package com.directnet.mobile_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.directnet.mobile_app/wifi_p2p"
    private var wifiDirectManager: WifiDirectManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        wifiDirectManager = WifiDirectManager(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "createGroup" -> {
                    wifiDirectManager?.createGroup(result) ?: result.error("NOT_READY", "Wi-Fi Direct Manager not initialized", null)
                }
                "removeGroup" -> {
                    wifiDirectManager?.removeGroup(result) ?: result.success(true)
                }
                "getGroupInfo" -> {
                    wifiDirectManager?.getGroupInfo(result) ?: result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        wifiDirectManager?.unregisterReceiver()
        super.onDestroy()
    }
}
