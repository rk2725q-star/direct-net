package com.directnet.mobile_app

import android.content.Intent
import android.os.Build
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
                    startGatewayForegroundService()
                    wifiDirectManager?.createGroup(result) ?: result.error("NOT_READY", "Wi-Fi Direct Manager not initialized", null)
                }
                "removeGroup" -> {
                    stopGatewayForegroundService()
                    wifiDirectManager?.removeGroup(result) ?: result.success(true)
                }
                "getGroupInfo" -> {
                    wifiDirectManager?.getGroupInfo(result) ?: result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startGatewayForegroundService() {
        try {
            val intent = Intent(this, GatewayService::class.java).apply {
                action = GatewayService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (_: Throwable) {}
    }

    private fun stopGatewayForegroundService() {
        try {
            val intent = Intent(this, GatewayService::class.java).apply {
                action = GatewayService.ACTION_STOP
            }
            startService(intent)
        } catch (_: Throwable) {}
    }

    override fun onDestroy() {
        wifiDirectManager?.unregisterReceiver()
        super.onDestroy()
    }
}
