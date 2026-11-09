package com.directnet.tv_app

import android.app.Service
import android.content.Intent
import android.os.IBinder

class TunnelService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
}

