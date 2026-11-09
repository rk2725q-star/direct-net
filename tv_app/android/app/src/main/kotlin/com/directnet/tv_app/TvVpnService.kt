package com.directnet.tv_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import hev.htproxy.TProxyService
import java.io.File
import java.io.FileOutputStream

class TvVpnService : VpnService() {
    companion object {
        const val ACTION_START = "com.directnet.tv_app.START"
        const val ACTION_STOP = "com.directnet.tv_app.STOP"
        const val EXTRA_HOST = "proxy_host"
        const val EXTRA_PORT = "proxy_port"
        const val CHANNEL_ID = "directnet_tv_vpn"

        var isRunning: Boolean = false
            private set
    }

    private var vpnInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // ALWAYS call startForeground immediately before any logic to satisfy Android 8+ requirement!
        startForegroundServiceNotification()

        when (intent?.action) {
            ACTION_START -> {
                val host = intent.getStringExtra(EXTRA_HOST) ?: "192.168.49.1"
                val port = intent.getIntExtra(EXTRA_PORT, 10808)
                startVpn(host, port)
            }
            ACTION_STOP -> {
                stopVpn()
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun startVpn(proxyHost: String, proxyPort: Int) {
        if (isRunning) {
            stopVpn()
        }

        try {
            // Write hev-socks5-tunnel yaml config with built-in MAPDNS
            // mapdns translates all local TV app DNS lookups into Fake IPs and routes them via SOCKS5 domain CONNECT!
            val configFile = File(cacheDir, "tunnel.yml")
            val configContent = """
tunnel:
  name: tun0
  mtu: 1500
  multi-queue: false
  ipv4: 172.19.0.1
  ipv6: 'fc00::1'

socks5:
  port: $proxyPort
  address: '$proxyHost'
  udp: 'tcp'

mapdns:
  address: 172.19.0.2
  port: 53
  network: 198.18.0.0
  netmask: 255.255.0.0
  cache-size: 10000

misc:
  task-stack-size: 86016
  tcp-buffer-size: 131072
  connect-timeout: 10000
  tcp-read-write-timeout: 300000
  udp-read-write-timeout: 60000
  log-file: stdout
  log-level: 'warn'
""".trimIndent()

            FileOutputStream(configFile).use { it.write(configContent.toByteArray()) }

            val builder = Builder()
                .setSession("DirectNet TV")
                .setMtu(1500)
                .addAddress("172.19.0.1", 24)
                .addDnsServer("172.19.0.2") // ONLY route TV DNS to mapdns resolver!
                .addRoute("0.0.0.0", 0)

            // Exclude DirectNet TV app itself so its sockets bypass the tunnel and reach the phone proxy
            try {
                builder.addDisallowedApplication(packageName)
            } catch (_: Throwable) {}

            vpnInterface = builder.establish()

            if (vpnInterface != null) {
                val fd = vpnInterface!!.fd
                val started = TProxyService.TProxyStartService(configFile.absolutePath, fd)
                if (started) {
                    isRunning = true
                }
            }
        } catch (e: Throwable) {
            e.printStackTrace()
            stopVpn()
        }
    }

    private fun stopVpn() {
        try {
            TProxyService.TProxyStopService()
        } catch (_: Throwable) {}

        try {
            vpnInterface?.close()
        } catch (_: Throwable) {}

        vpnInterface = null
        isRunning = false
    }

    private fun startForegroundServiceNotification() {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "DirectNet TV Tunnel",
                    NotificationManager.IMPORTANCE_LOW
                )
                manager.createNotificationChannel(channel)
            }

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

            val notification = builder
                .setContentTitle("DirectNet TV Active")
                .setContentText("All TV apps routing internet through Phone Gateway")
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(1001, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(1001, notification)
            }
        } catch (_: Throwable) {
            try {
                @Suppress("DEPRECATION")
                val fallbackNotification = Notification.Builder(this)
                    .setContentTitle("DirectNet TV")
                    .setSmallIcon(android.R.drawable.stat_sys_download_done)
                    .build()
                startForeground(1001, fallbackNotification)
            } catch (_: Throwable) {}
        }
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }
}
