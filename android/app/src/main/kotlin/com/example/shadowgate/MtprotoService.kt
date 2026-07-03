package com.example.shadowgate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import com.sun.jna.Library
import com.sun.jna.Native
import com.sun.jna.Pointer
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Android Foreground Service для MTProto прокси.
 *
 * Использует нативную Rust-библиотеку (libmtproto_proxy.so) через JNA.
 * Реализует foreground service с уведомлением и wake lock.
 */
class MtprotoService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private var statsJob: Job? = null
    private var lastNotificationContent: String = ""
    private var lastNotificationAtMs: Long = 0L
    private var notificationStartedAtMs: Long = 0L
    @Volatile
    private var stopInProgress = false
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Сохранённые параметры для перезапуска
    private var lastBindIp: String = "127.0.0.1"
    private var lastPort: Int = 1443
    private var lastIps: String = ""
    private var lastPoolSize: Int = 4
    private var lastCfEnabled: Boolean = true
    private var lastCfPriority: Boolean = true
    private var lastCfDomain: String = ""
    private var lastSecretKey: String = ""

    companion object {
        const val ACTION_START = "com.example.shadowgate.MTPROTO_START"
        const val ACTION_STOP = "com.example.shadowgate.MTPROTO_STOP"
        const val ACTION_RESTART = "com.example.shadowgate.MTPROTO_RESTART"
        const val EXTRA_BIND_IP = "EXTRA_BIND_IP"
        const val EXTRA_PORT = "EXTRA_PORT"
        const val EXTRA_IPS = "EXTRA_IPS"
        const val EXTRA_POOL_SIZE = "EXTRA_POOL_SIZE"
        const val EXTRA_CFPROXY_ENABLED = "EXTRA_CFPROXY_ENABLED"
        const val EXTRA_CFPROXY_PRIORITY = "EXTRA_CFPROXY_PRIORITY"
        const val EXTRA_CFPROXY_DOMAIN = "EXTRA_CFPROXY_DOMAIN"
        const val EXTRA_SECRET_KEY = "EXTRA_SECRET_KEY"

        private const val NOTIFICATION_ID = 102
        private const val CHANNEL_ID = "ShadowGate_MTProto_v2"
        private const val TAG = "MtprotoService"

        private const val WAKELOCK_TIMEOUT_MS = 30L * 60 * 1000
        private const val WAKELOCK_REFRESH_MS = 25L * 60 * 1000
        private const val STATS_UPDATE_MS = 3_000L
        private const val NOTIFICATION_MIN_UPDATE_MS = 3_000L
        private const val NATIVE_STOP_WAIT_MS = 3_000L

        private val _isRunning = MutableStateFlow(false)
        val isRunning: StateFlow<Boolean> = _isRunning
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val bindIp = intent.getStringExtra(EXTRA_BIND_IP) ?: "127.0.0.1"
                val port = intent.getIntExtra(EXTRA_PORT, 1443)
                val ips = intent.getStringExtra(EXTRA_IPS) ?: ""
                val poolSize = intent.getIntExtra(EXTRA_POOL_SIZE, 4)
                val cfEnabled = intent.getBooleanExtra(EXTRA_CFPROXY_ENABLED, true)
                val cfPriority = intent.getBooleanExtra(EXTRA_CFPROXY_PRIORITY, true)
                val cfDomain = intent.getStringExtra(EXTRA_CFPROXY_DOMAIN) ?: ""
                val secretKey = intent.getStringExtra(EXTRA_SECRET_KEY) ?: ""
                startProxy(bindIp, port, ips, poolSize, cfEnabled, cfPriority, cfDomain, secretKey)
            }
            ACTION_STOP -> stopProxy()
            ACTION_RESTART -> restartProxy()
            null -> {
                // Перезапуск после убийства системой
                if (lastPort > 0 && lastSecretKey.isNotEmpty()) {
                    android.util.Log.w(TAG, "Service restarted by system, re-starting proxy")
                    startProxy(lastBindIp, lastPort, lastIps, lastPoolSize, lastCfEnabled, lastCfPriority, lastCfDomain, lastSecretKey)
                } else {
                    stopSelf()
                }
            }
        }
        return START_REDELIVER_INTENT
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopProxy()
        super.onDestroy()
    }

    private fun startProxy(
        bindIp: String, port: Int, ips: String, poolSize: Int = 4,
        cfEnabled: Boolean = true, cfPriority: Boolean = true,
        cfDomain: String = "", secretKey: String = ""
    ) {
        if (_isRunning.value || stopInProgress) return

        // Сохраняем параметры
        lastBindIp = bindIp
        lastPort = port
        lastIps = ips
        lastPoolSize = poolSize
        lastCfEnabled = cfEnabled
        lastCfPriority = cfPriority
        lastCfDomain = cfDomain
        lastSecretKey = secretKey
        notificationStartedAtMs = System.currentTimeMillis()
        lastNotificationContent = "Запуск..."
        lastNotificationAtMs = notificationStartedAtMs

        val notification = createNotification(lastNotificationContent)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        acquireWakeLock()
        stopInProgress = false

        // Запускаем нативный прокси в отдельном потоке
        Thread({
            try {
                NativeProxy.setPoolSize(poolSize)
                NativeProxy.setCfProxyConfig(cfEnabled, cfPriority, cfDomain)
                val result = NativeProxy.startProxy(bindIp, port, ips, secretKey, 1)
                if (result != 0) {
                    android.util.Log.e(TAG, "StartProxy returned error code: $result")
                    serviceScope.launch {
                        updateNotification("Ошибка запуска: код $result", force = true)
                        delay(3000)
                        stopProxy()
                    }
                }
            } catch (e: Throwable) {
                android.util.Log.e(TAG, "Failed to start proxy via JNA", e)
                serviceScope.launch {
                    updateNotification("Ошибка: ${e.message ?: ""}", force = true)
                    delay(3000)
                    stopProxy()
                }
            }
        }, "ProxyStart").apply {
            isDaemon = true
            start()
        }

        updateRunningState(true)

        // Stats updater
        statsJob = serviceScope.launch {
            while (isActive) {
                delay(STATS_UPDATE_MS)
                if (_isRunning.value) {
                    try {
                        val stats = NativeProxy.getStats()
                        if (stats != null) {
                            updateNotification(stats)
                        }
                    } catch (_: Exception) {}
                }
            }
        }
    }

    private fun stopProxy() {
        if (stopInProgress) return
        stopInProgress = true

        statsJob?.cancel()
        statsJob = null

        Thread({
            try {
                NativeProxy.stopProxy()
            } catch (_: Exception) {}
        }, "ProxyStop").apply {
            isDaemon = true
            start()
        }

        releaseWakeLock()
        updateRunningState(false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun restartProxy() {
        serviceScope.launch {
            stopProxy()
            delay(500)
            startProxy(lastBindIp, lastPort, lastIps, lastPoolSize, lastCfEnabled, lastCfPriority, lastCfDomain, lastSecretKey)
        }
    }

    private fun updateRunningState(running: Boolean) {
        _isRunning.value = running
        isRunning.value = running
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ShadowGate:MtprotoWakeLock")
            wakeLock?.acquire(WAKELOCK_TIMEOUT_MS)
        } catch (_: Exception) {}
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.release()
        } catch (_: Exception) {}
        wakeLock = null
    }

    private suspend fun updateNotification(content: String, force: Boolean = false) {
        val now = System.currentTimeMillis()
        if (!force && now - lastNotificationAtMs < NOTIFICATION_MIN_UPDATE_MS) return
        lastNotificationContent = content
        lastNotificationAtMs = now

        val notification = createNotification(content)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ShadowGate MTProto",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "MTProto proxy service"
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun createNotification(content: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ShadowGate MTProto")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}

// ============================================================
// JNA Native interface
// ============================================================

interface MtprotoProxyLibrary : Library {
    companion object {
        val INSTANCE = Native.load("mtproto_proxy", MtprotoProxyLibrary::class.java) as MtprotoProxyLibrary
    }

    fun StartProxy(host: String, port: Int, dcIps: String, secret: String, verbose: Int): Int
    fun StopProxy(): Int
    fun SetPoolSize(size: Int)
    fun SetCfProxyCacheDir(cacheDir: String)
    fun SetCfProxyConfig(enabled: Int, priority: Int, userDomain: String)
    fun SetSecret(secret: String)
    fun GetSecretWithPrefix(): Pointer?
    fun GetStats(): Pointer?
    fun FreeString(p: Pointer)
}

object NativeProxy {
    fun startProxy(host: String, port: Int, dcIps: String, secret: String, verbose: Int): Int {
        return MtprotoProxyLibrary.INSTANCE.StartProxy(host, port, dcIps, secret, verbose)
    }

    fun stopProxy(): Int {
        return MtprotoProxyLibrary.INSTANCE.StopProxy()
    }

    fun setPoolSize(size: Int) {
        MtprotoProxyLibrary.INSTANCE.SetPoolSize(size)
    }

    fun setCfProxyCacheDir(cacheDir: String) {
        MtprotoProxyLibrary.INSTANCE.SetCfProxyCacheDir(cacheDir)
    }

    fun setCfProxyConfig(enabled: Boolean, priority: Boolean, userDomain: String) {
        MtprotoProxyLibrary.INSTANCE.SetCfProxyConfig(
            if (enabled) 1 else 0,
            if (priority) 1 else 0,
            userDomain
        )
    }

    fun getSecretWithPrefix(): String? {
        val ptr = MtprotoProxyLibrary.INSTANCE.GetSecretWithPrefix() ?: return null
        val res = ptr.getString(0)
        MtprotoProxyLibrary.INSTANCE.FreeString(ptr)
        return res
    }

    fun getStats(): String? {
        val ptr = MtprotoProxyLibrary.INSTANCE.GetStats() ?: return null
        val res = ptr.getString(0)
        MtprotoProxyLibrary.INSTANCE.FreeString(ptr)
        return res
    }
}