package com.directnet.tv_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.directnet.tv_app/vpn"
    private val VPN_REQUEST_CODE = 1002
    private var pendingResult: MethodChannel.Result? = null
    private var pendingHost: String = "192.168.49.1"
    private var pendingPort: Int = 10808

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val host = call.argument<String>("host") ?: "192.168.49.1"
                    val port = call.argument<Int>("port") ?: 10808
                    startVpnFlow(host, port, result)
                }
                "stopVpn" -> {
                    stopVpnService()
                    result.success(true)
                }
                "isVpnRunning" -> {
                    result.success(TvVpnService.isRunning)
                }
                "getWifiGatewayIp" -> {
                    val ip = getWifiGatewayIp()
                    result.success(ip)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getWifiGatewayIp(): String? {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val dhcp = wifiManager?.dhcpInfo
            if (dhcp != null && dhcp.gateway != 0) {
                val gatewayInt = dhcp.gateway
                val ip = String.format(
                    "%d.%d.%d.%d",
                    gatewayInt and 0xff,
                    gatewayInt shr 8 and 0xff,
                    gatewayInt shr 16 and 0xff,
                    gatewayInt shr 24 and 0xff
                )
                if (ip != "0.0.0.0") {
                    return ip
                }
            }
        } catch (_: Throwable) {}
        return null
    }

    private fun startVpnFlow(host: String, port: Int, result: MethodChannel.Result) {
        try {
            val intent = VpnService.prepare(this)
            if (intent != null) {
                pendingResult = result
                pendingHost = host
                pendingPort = port
                startActivityForResult(intent, VPN_REQUEST_CODE)
            } else {
                launchVpnService(host, port)
                result.success(true)
            }
        } catch (e: Throwable) {
            result.error("VPN_PREPARE_ERROR", e.message, null)
        }
    }

    private fun launchVpnService(host: String, port: Int) {
        val intent = Intent(this, TvVpnService::class.java).apply {
            action = TvVpnService.ACTION_START
            putExtra(TvVpnService.EXTRA_HOST, host)
            putExtra(TvVpnService.EXTRA_PORT, port)
        }
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (_: Throwable) {
            try {
                startService(intent)
            } catch (_: Throwable) {}
        }
    }

    private fun stopVpnService() {
        val intent = Intent(this, TvVpnService::class.java).apply {
            action = TvVpnService.ACTION_STOP
        }
        try {
            startService(intent)
        } catch (_: Throwable) {}
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            val currentResult = pendingResult
            pendingResult = null
            if (resultCode == Activity.RESULT_OK) {
                try {
                    launchVpnService(pendingHost, pendingPort)
                    currentResult?.success(true)
                } catch (e: Throwable) {
                    currentResult?.error("VPN_START_ERROR", e.message, null)
                }
            } else {
                currentResult?.error("VPN_PERMISSION_DENIED", "VPN permission was not granted by user", null)
            }
        }
    }
}
