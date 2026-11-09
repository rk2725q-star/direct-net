package com.directnet.mobile_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

class GatewayService : Service() {
    companion object {
        const val ACTION_START = "com.directnet.mobile_app.START_GATEWAY"
        const val ACTION_STOP = "com.directnet.mobile_app.STOP_GATEWAY"
        const val CHANNEL_ID = "directnet_gateway_channel"
        const val NOTIFICATION_ID = 2024

        var isRunning: Boolean = false
            private set
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startGatewayForeground()
            ACTION_STOP -> stopGatewayForeground()
        }
        return START_STICKY
    }

    private fun startGatewayForeground() {
        if (isRunning) return
        createNotificationChannel()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val notification = builder
            .setContentTitle("DirectNet JioFiber Gateway Active")
            .setContentText("Sharing high-speed 5G internet with TV & devices (Screen-off enabled)")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Throwable) {
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (_: Throwable) {}
        }

        // 1. Acquire Partial WakeLock to keep CPU active when screen turns off
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "DirectNet::GatewayWakeLock").apply {
                setReferenceCounted(false)
                acquire(12 * 60 * 60 * 1000L) // 12 hours max safety
            }
        } catch (_: Throwable) {}

        // 2. Acquire High-Performance Wi-Fi Lock to prevent Wi-Fi power-save throttling (DTIM)
        try {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                @Suppress("DEPRECATION")
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifiLock = wm.createWifiLock(mode, "DirectNet::GatewayWifiLock").apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (_: Throwable) {}

        isRunning = true
    }

    private fun stopGatewayForeground() {
        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
            wakeLock = null
        } catch (_: Throwable) {}

        try {
            wifiLock?.let {
                if (it.isHeld) it.release()
            }
            wifiLock = null
        } catch (_: Throwable) {}

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Throwable) {}

        isRunning = false
        stopSelf()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "DirectNet Gateway Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps DirectNet Gateway running in background without interruptions"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopGatewayForeground()
        super.onDestroy()
    }
}
