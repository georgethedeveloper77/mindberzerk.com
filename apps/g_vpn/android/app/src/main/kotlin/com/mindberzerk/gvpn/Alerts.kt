package com.mindberzerk.gvpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * G VPN's own alerts (new device, weekly report, ...) as system
 * notifications. A plain method channel rather than Pigeon: two calls, and
 * the Pigeon interface stays as it is.
 *
 *   notify {id, title, body, route}  posts one; a tap opens the app at route
 *   launchRoute                       the route the app was opened with, once
 */
object Alerts {
    private const val CHANNEL_ID = "gvpn_alerts"
    private const val EXTRA_ROUTE = "gvpn.route"

    /** The route of the notification that opened the app, until read. */
    @Volatile
    private var pending: String? = null

    fun record(intent: Intent?) {
        intent?.getStringExtra(EXTRA_ROUTE)?.let { pending = it }
    }

    fun setUp(messenger: BinaryMessenger, ctx: Context) {
        MethodChannel(messenger, "com.mindberzerk.gvpn/alerts").setMethodCallHandler { call, result ->
            when (call.method) {
                "notify" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val route = call.argument<String>("route")
                    val channelName = call.argument<String>("channel") ?: "Alerts"
                    result.success(post(ctx.applicationContext, id, title, body, route, channelName))
                }
                "launchRoute" -> {
                    result.success(pending)
                    pending = null
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun post(app: Context, id: Int, title: String, body: String, route: String?, channelName: String): Boolean {
        val nm = app.getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= 33 && !nm.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_DEFAULT))
        }
        val launch = app.packageManager.getLaunchIntentForPackage(app.packageName)?.apply {
            if (route != null) putExtra(EXTRA_ROUTE, route)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        } ?: return false
        val tap = PendingIntent.getActivity(
            app,
            id,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(app, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(app)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_gvpn)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(true)
            .build()
        nm.notify(id, notification)
        return true
    }
}
