package com.example.shadowgate

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Канал для TUN/VPN сервиса
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ShadowVpnService.CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestVpnPermission" -> {
                    requestVpnPermission(result)
                }
                "startTun" -> {
                    val config = call.arguments as? Map<String, Any>
                    if (config != null) {
                        startTun(config, result)
                    } else {
                        result.error("INVALID_ARGS", "Invalid TUN config", null)
                    }
                }
                "stopTun" -> {
                    stopTun(result)
                }
                "getTunStatus" -> {
                    result.success(ShadowVpnService.running)
                }
                "checkAdminRights" -> {
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Канал для MTProto сервиса
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MtprotoService.CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMtproto" -> {
                    val args = call.arguments as? Map<String, Any>
                    if (args != null) {
                        startMtproto(args, result)
                    } else {
                        result.error("INVALID_ARGS", "Invalid MTProto config", null)
                    }
                }
                "stopMtproto" -> {
                    stopMtproto(result)
                }
                "getMtprotoStatus" -> {
                    result.success(mapOf(
                        "isRunning" to MtprotoService.isRunning,
                        "secret" to (MtprotoService.currentSecret ?: "")
                    ))
                }
                "generateSecret" -> {
                    val args = call.arguments as? Map<String, Any>
                    val useFakeTls = args?.get("useFakeTls") as? Boolean ?: true
                    val secret = if (useFakeTls) {
                        "dd" + generateRandomHex(16)
                    } else {
                        generateRandomHex(16)
                    }
                    result.success(secret)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun requestVpnPermission(result: MethodChannel.Result) {
        val intent = android.net.VpnService.prepare(this)
        if (intent != null) {
            startIntentSenderForResult(
                intent.intentSender,
                ShadowVpnService.VPN_REQUEST_CODE,
                null, 0, 0, 0
            )
            result.success(true)
        } else {
            result.success(true)
        }
    }

    private fun startTun(config: Map<String, Any>, result: MethodChannel.Result) {
        try {
            val intent = Intent(this, ShadowVpnService::class.java).apply {
                putExtra("config", HashMap(config))
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }

            // Даём время сервису запуститься
            Thread.sleep(300)

            result.success(ShadowVpnService.running)
        } catch (e: Exception) {
            result.error("VPN_ERROR", e.message, null)
        }
    }

    private fun stopTun(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, ShadowVpnService::class.java)
            stopService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("VPN_ERROR", e.message, null)
        }
    }

    // ========== MTProto методы ==========

    private fun startMtproto(args: Map<String, Any>, result: MethodChannel.Result) {
        try {
            val port = (args["port"] as? Int) ?: 1080
            val secret = args["secret"] as? String ?: ""
            val webSocketUrl = args["webSocketUrl"] as? String
                ?: "wss://pluto.web.telegram.org/apiws"

            val intent = Intent(this, MtprotoService::class.java).apply {
                putExtra("port", port)
                putExtra("secret", secret)
                putExtra("webSocketUrl", webSocketUrl)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }

            // Ждём запуска нативного сервера
            Thread.sleep(500)

            val generatedSecret = MtprotoService.currentSecret ?: secret
            result.success(generatedSecret)
        } catch (e: Exception) {
            result.error("MTPROTO_ERROR", e.message, null)
        }
    }

    private fun stopMtproto(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, MtprotoService::class.java)
            stopService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("MTPROTO_ERROR", e.message, null)
        }
    }

    private fun generateRandomHex(length: Int): String {
        val bytes = ByteArray(length)
        java.security.SecureRandom().nextBytes(bytes)
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
