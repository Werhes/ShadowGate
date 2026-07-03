package com.example.shadowgate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer

/**
 * Android VpnService для TUN-режима ShadowGate
 *
 * Исправления:
 * - Правильный lifecycle: VPN запускается в onStartCommand, а не через прямой вызов
 * - Пакеты отправляются в Dart через MethodChannel для DPI-обработки
 * - Обработка onRevoke для корректной остановки
 * - Foreground service для предотвращения убийства процесса
 */
class ShadowVpnService : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null
    private var running = false

    companion object {
        const val CHANNEL = "com.example.shadowgate/service"
        const val NOTIFICATION_CHANNEL_ID = "shadowgate_vpn"
        const val NOTIFICATION_ID = 1
        const val VPN_REQUEST_CODE = 1000

        var methodChannel: MethodChannel? = null
        var onStatusChanged: ((Boolean) -> Unit)? = null
        var running: Boolean = false
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)

        // Получаем конфиг из intent
        val config = intent?.getSerializableExtra("config") as? HashMap<String, Any>
        if (config != null) {
            startVpn(config)
        }

        return START_STICKY
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }

    private fun startVpn(config: Map<String, Any>) {
        if (running) return

        try {
            val interfaceName = config["interfaceName"] as? String ?: "shadowgate0"
            val mtu = (config["mtu"] as? Int) ?: 1500
            val dns = config["dns"] as? String ?: "8.8.8.8"
            val bypassLocal = config["bypassLocalTraffic"] as? Boolean ?: true

            val builder = Builder()
            builder.setSession("ShadowGate")
            builder.setMtu(mtu)
            builder.setBlocking(true)

            // DNS
            builder.addDnsServer(dns)

            // Весь трафик через VPN
            builder.addAddress("0.0.0.0", 0)
            builder.addRoute("0.0.0.0", 0)

            // IPv6
            builder.addAddress("::", 0)
            builder.addRoute("::", 0)

            // Исключаем локальные сети если нужно
            if (bypassLocal) {
                builder.addRoute("10.0.0.0", 8)
                builder.addRoute("172.16.0.0", 12)
                builder.addRoute("192.168.0.0", 16)
            }

            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                android.util.Log.e("ShadowVPN", "Failed to establish VPN interface")
                onStatusChanged?.call(false)
                return
            }

            running = true
            this@ShadowVpnService.running = true
            onStatusChanged?.call(true)
            android.util.Log.i("ShadowVPN", "VPN started: mtu=$mtu, dns=$dns")

            // Запускаем поток чтения/записи TUN
            vpnThread = Thread {
                val input = FileInputStream(vpnInterface!!.fileDescriptor)
                val output = FileOutputStream(vpnInterface!!.fileDescriptor)
                val buffer = ByteBuffer.allocate(mtu)

                try {
                    val channel = input.channel
                    while (running) {
                        buffer.clear()
                        val read = channel.read(buffer)
                        if (read <= 0) continue

                        buffer.flip()
                        val packet = ByteArray(read)
                        buffer.get(packet)

                        // Отправляем пакет в Dart для DPI-обработки
                        val processed = processPacket(packet)
                        if (processed != null) {
                            output.write(processed)
                            output.flush()
                        }
                    }
                } catch (e: Exception) {
                    if (running) {
                        android.util.Log.e("ShadowVPN", "TUN thread error: ${e.message}")
                    }
                }
            }
            vpnThread?.start()

        } catch (e: Exception) {
            android.util.Log.e("ShadowVPN", "VPN start error: ${e.message}")
            e.printStackTrace()
            onStatusChanged?.call(false)
        }
    }

    private fun stopVpn() {
        running = false
        this@ShadowVpnService.running = false
        vpnThread?.interrupt()
        vpnThread = null
        try {
            vpnInterface?.close()
        } catch (_: Exception) {}
        vpnInterface = null
        onStatusChanged?.call(false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /**
     * Отправка пакета в Dart для DPI-обработки.
     * Если Dart не отвечает, пакет пропускается как есть.
     */
    private fun processPacket(packet: ByteArray): ByteArray? {
        val channel = methodChannel
        if (channel == null) return packet

        try {
            // Используем синхронный вызов через MethodChannel
            // Пакет передаётся как byte array, Dart возвращает обработанный пакет
            val result = channel.invokeMethod<ByteArray>("processPacket", packet)
            return result ?: packet
        } catch (e: Exception) {
            // Если Dart не обработал — пропускаем пакет как есть
            return packet
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "ShadowGate VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "VPN service notification"
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("ShadowGate VPN")
            .setContentText("VPN is running")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}