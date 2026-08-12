package com.mindhunter.g_launcher

import android.content.Intent
import android.os.Bundle
import androidx.core.view.WindowCompat
import com.mindhunter.g_launcher.widgets.StageBridge
import com.mindhunter.g_launcher.widgets.WidgetStage
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

    /// Does the widget stage own the gesture currently in flight? Decided once,
    /// on ACTION_DOWN, and held until it ends. See dispatchTouchEvent.
    private var stageOwnsGesture = false

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

        // Every hosted third-party widget lives in a plain Android ViewGroup
        // BEHIND FlutterView, not in a PlatformView. See WidgetStage for why:
        // hybrid composition fails to allocate its overlay buffers on this
        // device's Adreno driver under Impeller, and the collapse of Flutter's
        // layering that follows is the black quad, the doubled clock, the
        // desklets bleeding through the drawer, and the 302MB of GL memory.
        //
        // Works because getBackgroundMode() below returns transparent, which
        // puts Flutter on a FlutterTextureView, which composites in the view
        // hierarchy. Same mechanism that lets the wallpaper through.
        WidgetStage.attach(this, widgetHost)
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
        WidgetStage.detach()
        widgetHost.detachActivity(this)
        super.onDestroy()
    }

    /**
     * Give a gesture to the widget under it, when there is one.
     *
     * ─── WHY THE ACTIVITY AND NOT THE STAGE ─────────────────────────────────
     *
     * FlutterView sits ON TOP of the stage and consumes everything, so a widget
     * behind it would never see a press no matter what the stage did with its
     * own touch flags. The only place that sees a MotionEvent before Flutter
     * does is here.
     *
     * ─── WHY THE WHOLE GESTURE, DECIDED ON DOWN ─────────────────────────────
     *
     * `owned` is set once, on ACTION_DOWN, and holds until the gesture ends. A
     * per-event decision would let a swipe that began on the wallpaper start
     * scrubbing a media widget the moment it passed over one, and would tear a
     * drag in half the moment it left one.
     *
     * ─── WHY THIS DOES NOT STEAL FLUTTER'S DESKTOP GESTURES ─────────────────
     *
     * [WidgetStage.hitTest] returns false whenever the stage is hidden, and Dart
     * hides it during edit mode, during a workspace swipe, and whenever the
     * drawer or any full-screen surface is open. So the only presses diverted
     * are ones that land on a live widget on a desktop at rest, which is exactly
     * when the user means to press the widget.
     */
    override fun dispatchTouchEvent(ev: android.view.MotionEvent): Boolean {
        when (ev.actionMasked) {
            android.view.MotionEvent.ACTION_DOWN ->
                stageOwnsGesture = WidgetStage.hitTest(ev.x, ev.y)

            android.view.MotionEvent.ACTION_UP,
            android.view.MotionEvent.ACTION_CANCEL -> {
                if (stageOwnsGesture) {
                    stageOwnsGesture = false
                    // Delivered here rather than after the reset, so the widget
                    // still receives the UP that completes its own gesture. A
                    // press that never gets its release leaves a media button
                    // stuck highlighted.
                    if (WidgetStage.dispatch(ev)) return true
                }
            }
        }

        if (stageOwnsGesture && WidgetStage.dispatch(ev)) return true
        return super.dispatchTouchEvent(ev)
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

        // The widget stage's channel. Set up HERE rather than in
        // LauncherApplication because the stage belongs to a window and this is
        // the object that has one. Re-registering on a recreate is harmless:
        // setMethodCallHandler replaces rather than stacks.
        StageBridge.setUp(flutterEngine.dartExecutor.binaryMessenger)
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
