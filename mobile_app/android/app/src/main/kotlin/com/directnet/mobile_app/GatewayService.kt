package com.directnet.mobile_app

import android.app.Service
import android.content.Intent
import android.os.IBinder

class GatewayService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
}

