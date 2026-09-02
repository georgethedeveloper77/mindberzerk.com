package com.mindhunter.g_launcher.apps

import android.app.Activity
import android.content.Context
import android.content.pm.LauncherApps
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import com.mindhunter.g_launcher.LauncherApplication

/**
 * The activity whose EXISTENCE is the fix.
 *
 * `ShortcutManager.isRequestPinShortcutSupported()` asks the system whether the
 * current default launcher declares an activity for
 * ACTION_CONFIRM_PIN_SHORTCUT. Chrome calls that before offering to add a site
 * to the home screen, and while this activity did not exist the answer was no
 * and the install was abandoned silently. Nothing was logged, nothing was
 * shown, and from the outside it looked like G Launcher had no PWA support.
 *
 * ─── NO UI, AND THAT IS ON PURPOSE ──────────────────────────────────────────
 *
 * The instinct is to show a themed confirmation sheet here. It would be the
 * second dialog in a row asking the same question: Chrome has already shown
 * "Install <site>?" and the user has already tapped it. So this accepts, tells
 * the user it happened, and gets out of the way.
 *
 * That also keeps this activity out of the Flutter engine entirely. Routing
 * through Dart to draw a sheet would mean attaching the cached engine to a
 * second Activity while `LauncherActivity` may still hold it, which is a real
 * mess for a screen nobody wanted.
 *
 * ─── THE MESSAGE IS A TOAST, AND ONLY HERE ──────────────────────────────────
 *
 * Every transient message in this app goes through the branded scaffold
 * component and never through a SnackBar or a Toast. That rule is about
 * SURFACES WE DRAW: it exists so the launcher's own messages look like the
 * launcher. This activity draws nothing, has no Flutter engine attached and
 * finishes before a frame, so there is no scaffold to put a message in. A Toast
 * is the only thing that can speak from here.
 *
 * Do not take this as licence to use one anywhere else.
 */
class PinShortcutActivity : Activity() {

    private companion object {
        const val TAG = "GLauncherWebApps"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val added = runCatching { handle() }.getOrElse {
            Log.w(TAG, "pin request failed: $it")
            false
        }

        if (added) {
            // Hardcoded rather than a string resource, and it is the one
            // authored string in this pass that is not translated. The i18n
            // sweep uses the English string AS the key, and this file has no
            // Flutter context to resolve one through. It joins that sweep.
            Toast.makeText(this, "Added to G Launcher", Toast.LENGTH_SHORT).show()
        }

        // Finished either way and with no result. The requesting app is not
        // waiting on us: `accept()` is what it observes, and a refused or
        // malformed request has nothing to report back.
        finish()
    }

    private fun handle(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false

        val launcherApps =
            getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
        val request = launcherApps.getPinItemRequest(intent) ?: return false

        val repo = ShortcutRepository(this)
        if (!repo.acceptPin(request)) return false

        // The app list must be rebuilt before anything reads it again. Routed
        // through the watcher rather than calling `refresh()` here, so this
        // shares the 250ms debounce and the foreground gate with every other
        // change: accepting three pins in a burst enumerates once, and a pin
        // that lands while the desktop is not on screen is deferred until it
        // is, exactly like a package install.
        // `hostApi` is a lateinit built in `LauncherApplication.onCreate`. It
        // is initialised long before any browser can reach this activity, but
        // reading an uninitialised lateinit THROWS rather than returning null,
        // and a crash here would be a crash inside someone else's install
        // flow. runCatching rather than a readiness flag, so this needs no
        // change to LauncherApplication at all.
        runCatching {
            (application as LauncherApplication).hostApi.webAppsChanged()
        }.onFailure { Log.w(TAG, "could not refresh after pin: $it") }
        return true
    }
}
