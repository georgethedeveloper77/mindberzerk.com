package com.mindhunter.g_launcher

import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.StringCodec


/**
 * Attaches to the engine warmed in LauncherApplication instead of creating one.
 * That is what getCachedEngineId() does, and it is the whole point.
 */
class LauncherActivity : FlutterActivity() {

    private var homeChannel: BasicMessageChannel<String>? = null

    /// The process-wide AppWidget host, owned by LauncherApplication. Binding and
    /// configuring a widget need an Activity, so this Activity lends itself to
    /// the host while it is alive.
    private val widgetHost get() = (application as LauncherApplication).widgetHost

    override fun getCachedEngineId(): String = LauncherApplication.ENGINE_ID

    /**
     * false — do NOT destroy the engine when this activity finishes. The engine
     * outlives the activity and belongs to the process.
     */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Draw behind the status and nav bars. A desktop shell paints its own
        // top bar; it cannot do that under a system-reserved inset.
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Lend this Activity to the widget host for the bind/config result flow.
        widgetHost.attachActivity(this)
    }

    /**
     * The host must be listening for its views to receive RemoteViews updates.
     * Tied to start/stop so a backgrounded launcher stops updating hosted
     * widgets, which is the whole reason AppWidgetHost has this pair.
     */
    override fun onStart() {
        super.onStart()
        widgetHost.startListening()
    }

    override fun onStop() {
        widgetHost.stopListening()
        super.onStop()
    }

    override fun onDestroy() {
        widgetHost.detachActivity(this)
        super.onDestroy()
    }

    /**
     * The bind-permission dialog and a provider's config Activity both come back
     * here. Hand them to the host first; it returns true when it consumed one.
     */
    @Deprecated("Superseded by the Activity Result APIs; still the reliable path with a warmed engine.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (widgetHost.onActivityResult(requestCode, resultCode)) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        homeChannel = BasicMessageChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "g_launcher/home_press",
            StringCodec.INSTANCE,
        )
    }

    /**
     * With launchMode=singleTask, a HOME press while the launcher is already
     * resumed does not restart the activity — it lands here.
     *
     * This is the "press home to go home" behaviour every launcher needs:
     * close the drawer, dismiss the palette, return to workspace 1. Handle it
     * in Dart; native just says it happened.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.hasCategory(Intent.CATEGORY_HOME)) {
            homeChannel?.send("home")
        }
    }

    /**
     * Back must never leave the launcher. The system treats a launcher's back
     * as "do nothing" — Dart decides whether to close a drawer or ignore it.
     */
    @Deprecated("Superseded by predictive back; still the reliable path today.")
    override fun onBackPressed() {
        // super does NOT finish the activity. FlutterActivity.onBackPressed only
        // sends popRoute over the navigation channel; if Dart's PopScope refuses,
        // nothing happens, which is exactly "back never leaves the launcher".
        // Swallowing it here severed the channel instead.
        super.onBackPressed()
    }

    /**
     * THE line that lets the system wallpaper show through.
     *
     * FlutterActivity renders onto an opaque SurfaceView by default, which paints
     * black over the wallpaper no matter what the window theme says. Transparent
     * mode switches it to a translucent surface.
     *
     * Costs a little GPU (no more opaque-surface fast path) — the price of being
     * a launcher rather than an app.
     */
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent
}
