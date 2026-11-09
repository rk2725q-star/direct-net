package com.directnet.mobile_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.NetworkInfo
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pGroup
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

class WifiDirectManager(private val context: Context) {
    companion object {
        const val DESIRED_SSID = "DIRECT-5G-JioFiber"
        const val DESIRED_PASS = "87654321"
    }

    private val p2pManager: WifiP2pManager? =
        context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    private val channel: WifiP2pManager.Channel? =
        p2pManager?.initialize(context, Looper.getMainLooper(), null)

    private val mainHandler = Handler(Looper.getMainLooper())
    private var isReceiverRegistered = false
    private var activeGroup: WifiP2pGroup? = null

    private var isGatewayActive = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            when (intent?.action) {
                WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                    val networkInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(WifiP2pManager.EXTRA_NETWORK_INFO, NetworkInfo::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(WifiP2pManager.EXTRA_NETWORK_INFO)
                    }
                    if (networkInfo?.isConnected == true) {
                        fetchGroupInfo(null)
                    } else if (isGatewayActive && activeGroup == null) {
                        // Prevent idle drop by reviving group
                        mainHandler.postDelayed({
                            if (isGatewayActive && activeGroup == null) {
                                initiateCreateGroup(null)
                            }
                        }, 1200)
                    }
                }
            }
        }
    }

    private fun registerReceiver() {
        if (!isReceiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
                addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    context.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
                } else {
                    context.registerReceiver(receiver, filter)
                }
                isReceiverRegistered = true
            } catch (_: Exception) {}
        }
    }

    fun unregisterReceiver() {
        if (isReceiverRegistered) {
            try {
                context.unregisterReceiver(receiver)
            } catch (_: Exception) {}
            isReceiverRegistered = false
        }
    }

    fun createGroup(result: MethodChannel.Result) {
        if (p2pManager == null || channel == null) {
            result.error("P2P_NOT_AVAILABLE", "Wi-Fi Direct is not supported on this device", null)
            return
        }

        isGatewayActive = true
        registerReceiver()

        try {
            // If an active group is already broadcasting, reuse it immediately!
            p2pManager.requestGroupInfo(channel) { existingGroup ->
                if (existingGroup != null &&
                    existingGroup.isGroupOwner &&
                    !existingGroup.networkName.isNullOrEmpty()
                ) {
                    activeGroup = existingGroup
                    result.success(buildGroupMap(existingGroup))
                    return@requestGroupInfo
                }

                // Stop any background discovery scan that could lock the Wi-Fi chip into BUSY mode
                try {
                    p2pManager.stopPeerDiscovery(channel, null)
                } catch (_: Exception) {}

                initiateCreateGroup(result)
            }
        } catch (e: Exception) {
            initiateCreateGroup(result)
        }
    }

    private fun initiateCreateGroup(result: MethodChannel.Result?) {
        val mgr = p2pManager
        val ch = channel
        if (mgr == null || ch == null) {
            result?.error("P2P_UNAVAILABLE", "Wi-Fi Direct subsystem unavailable", null)
            return
        }

        // Action listener to handle standard group creation
        val fallbackListener = object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                pollGroupInfo(result, 0)
            }

            override fun onFailure(reason: Int) {
                // If busy, wait 500ms and try once more
                if (reason == WifiP2pManager.BUSY) {
                    mainHandler.postDelayed({
                        mgr.createGroup(ch, object : WifiP2pManager.ActionListener {
                            override fun onSuccess() { pollGroupInfo(result, 0) }
                            override fun onFailure(r2: Int) { pollGroupInfo(result, 0) }
                        })
                    }, 500)
                } else {
                    pollGroupInfo(result, 0)
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val config = WifiP2pConfig.Builder()
                    .setNetworkName(DESIRED_SSID)
                    .setPassphrase(DESIRED_PASS)
                    .setGroupOperatingBand(WifiP2pConfig.GROUP_OWNER_BAND_2GHZ)
                    .build()

                mgr.createGroup(ch, config, object : WifiP2pManager.ActionListener {
                    override fun onSuccess() {
                        pollGroupInfo(result, 0)
                    }

                    override fun onFailure(reason: Int) {
                        // Custom SSID rejected by OEM driver (e.g. Realme/Oppo) -> Immediately launch standard group
                        mgr.createGroup(ch, fallbackListener)
                    }
                })
                return
            } catch (_: Exception) {}
        }

        // Standard autonomous group creation
        mgr.createGroup(ch, fallbackListener)
    }

    private fun pollGroupInfo(result: MethodChannel.Result?, attempt: Int) {
        if (attempt >= 20) {
            fetchGroupInfo { g ->
                if (g != null && !g.networkName.isNullOrEmpty()) {
                    activeGroup = g
                    result?.success(buildGroupMap(g))
                } else {
                    result?.error(
                        "WIFI_DIRECT_TIMEOUT",
                        "Wi-Fi Direct did not start. Please ensure Wi-Fi and Location are ON in phone settings.",
                        null
                    )
                }
            }
            return
        }

        mainHandler.postDelayed({
            fetchGroupInfo { group ->
                if (group != null && !group.networkName.isNullOrEmpty()) {
                    activeGroup = group
                    result?.success(buildGroupMap(group))
                } else {
                    pollGroupInfo(result, attempt + 1)
                }
            }
        }, 300)
    }

    fun fetchGroupInfo(callback: ((WifiP2pGroup?) -> Unit)?) {
        try {
            p2pManager?.requestGroupInfo(channel) { group ->
                if (group != null && !group.networkName.isNullOrEmpty()) {
                    activeGroup = group
                }
                callback?.invoke(group)
            }
        } catch (_: Exception) {
            callback?.invoke(null)
        }
    }

    fun removeGroup(result: MethodChannel.Result?) {
        isGatewayActive = false
        if (p2pManager == null || channel == null) {
            activeGroup = null
            result?.success(true)
            return
        }

        try {
            p2pManager.removeGroup(channel, object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    activeGroup = null
                    unregisterReceiver()
                    result?.success(true)
                }

                override fun onFailure(reason: Int) {
                    activeGroup = null
                    unregisterReceiver()
                    result?.success(true)
                }
            })
        } catch (_: Exception) {
            activeGroup = null
            unregisterReceiver()
            result?.success(true)
        }
    }

    fun getGroupInfo(result: MethodChannel.Result) {
        fetchGroupInfo { group ->
            if (group != null) {
                result.success(buildGroupMap(group))
            } else {
                result.success(buildFallbackMap())
            }
        }
    }

    private fun buildGroupMap(group: WifiP2pGroup): Map<String, Any?> {
        val ssid = if (!group.networkName.isNullOrEmpty()) group.networkName else DESIRED_SSID
        val pass = if (!group.passphrase.isNullOrEmpty()) group.passphrase else DESIRED_PASS

        return mapOf(
            "ssid" to ssid,
            "passphrase" to pass,
            "ip" to "192.168.49.1",
            "port" to 10808,
            "isOwner" to group.isGroupOwner,
            "interfaceName" to (group.`interface` ?: "p2p0")
        )
    }

    private fun buildFallbackMap(): Map<String, Any?> {
        return mapOf(
            "ssid" to DESIRED_SSID,
            "passphrase" to DESIRED_PASS,
            "ip" to "192.168.49.1",
            "port" to 10808,
            "isOwner" to true,
            "interfaceName" to "p2p0"
        )
    }
}
