package com.mindhunter.g_launcher.system

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings

/**
 * Becoming the home app, and deep-linking into the OS.
 *
 * Deliberately NOT RoleManager.requestRole(ROLE_HOME). That path gives a nicer
 * in-app dialog, but it needs an Activity + onActivityResult plumbing, and
 * several OEMs — Samsung and Xiaomi in particular, i.e. most of the actual
 * audience — intercept or silently ignore it. ACTION_HOME_SETTINGS is dull,
 * needs only an application Context, and works on every device.
 */
class RoleRequester(context: Context) {

    private val appContext = context.applicationContext
    private val packageManager: PackageManager = appContext.packageManager

    /**
     * Resolves the CURRENT home app and compares it to us. Returns false while
     * the system chooser is still showing "always / just once", which is right:
     * we are not the default until the user says so.
     */
    fun isDefaultLauncher(): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = packageManager.resolveActivity(
            intent,
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        return resolved?.activityInfo?.packageName == appContext.packageName
    }

    fun requestDefaultLauncher() {
        val intent = Intent(Settings.ACTION_HOME_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (intent.resolveActivity(packageManager) != null) {
            appContext.startActivity(intent)
            return
        }

        // A few OEM builds hide ACTION_HOME_SETTINGS. Fall back to our own app
        // details page, which also has a "Set as default" route.
        openSettings(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
    }

    /**
     * Deep-links a real Android settings screen.
     *
     * Reimplementing OS settings is how launchers rot: the OEM changes
     * something, and your copy is quietly wrong forever. Send people to the
     * real screen instead.
     */
    fun openSettings(action: String) {
        val intent = Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (action == Settings.ACTION_APPLICATION_DETAILS_SETTINGS) {
            intent.data = Uri.parse("package:${appContext.packageName}")
        }

        // An unresolvable action is a no-op, never a crash. OEM ROMs remove
        // screens, and a Settings row must not be able to kill the launcher.
        if (intent.resolveActivity(packageManager) != null) {
            appContext.startActivity(intent)
        }
    }
}
