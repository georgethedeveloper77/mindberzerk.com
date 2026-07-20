package com.mindhunter.g_launcher.system

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings

/**
 * We do NOT reimplement Android's settings. We wear One UI's clothes and then
 * hand the user to the real thing. Cheap to build, impossible to get wrong,
 * and it never goes stale when the OS changes.
 */
object SettingsIntents {

    fun openHomeSettings(context: Context) =
        context.startActivity(Intent(Settings.ACTION_HOME_SETTINGS).newTask())

    fun openDisplaySettings(context: Context) =
        context.startActivity(Intent(Settings.ACTION_DISPLAY_SETTINGS).newTask())

    fun openNotificationSettings(context: Context) =
        context.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).newTask())

    fun openAppInfo(context: Context, packageName: String) =
        context.startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName"),
            ).newTask()
        )

    private fun Intent.newTask(): Intent = addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
}
