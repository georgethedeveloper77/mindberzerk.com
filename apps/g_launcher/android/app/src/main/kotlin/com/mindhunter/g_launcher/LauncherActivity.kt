package com.mindhunter.g_launcher

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import com.mindhunter.g_launcher.system.WallpaperOffsets
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

    /// The app-list host API. Borrowed for the same reason as [widgetHost]:
    /// starting the system's uninstall confirmation needs an Activity, so that
    /// it lands on the launcher's own task instead of asking the window manager
    /// for a new one over the home task, which One UI does not honour.
    private val hostApi get() = (application as LauncherApplication).hostApi

    /// The keystore bridge, lent this Activity for the SSH key prompt.
    private val keysApi get() = (application as LauncherApplication).keysApi

    override fun getCachedEngineId(): String = LauncherApplication.ENGINE_ID

    /**
     * false — do NOT destroy the engine when this activity finishes. The engine
     * outlives the activity and belongs to the process.
     */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    /** See [LauncherApplication.installComplete]. */
    private val installComplete
        get() = (application as LauncherApplication).installComplete

    override fun onCreate(savedInstanceState: Bundle?) {
        // ─── AN INCOMPLETE INSTALL GOES SOMEWHERE USEFUL ────────────────────
        //
        // With no Flutter library the Application built no engine, and
        // FlutterActivity's own onCreate throws looking for it. That throw comes
        // AFTER Activity.onCreate has run inside super, so catching it here is
        // safe, and the user gets a screen that explains the fix instead of
        // "G Launcher keeps stopping" on every press of home.
        if (!installComplete) {
            try {
                super.onCreate(savedInstanceState)
            } catch (_: IllegalStateException) {
                // No cached engine: expected on this path.
            }
            startActivity(Intent(this, BrokenInstallActivity::class.java))
            finish()
            return
        }
        super.onCreate(savedInstanceState)

        // Draw behind the status and nav bars. A desktop shell paints its own
        // top bar; it cannot do that under a system-reserved inset.
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // ─── AND THEN TURN OFF THE SCRIM THE SYSTEM ADDS BACK ───────────────
        //
        // `navigationBarColor` is already transparent in styles.xml, and the
        // platform's answer to a transparent navigation bar is to paint an 80%
        // opaque background behind it whenever the device is on three-button
        // navigation. `isNavigationBarContrastEnforced` defaults to TRUE, so
        // that happens without anything in this project asking for it.
        //
        // On gesture navigation there is no scrim and this line changes
        // nothing, which is why it has never shown up on the S22. On a
        // three-button device it is a grey band across the bottom of every
        // wallpaper, under every distro, and it looks like the wallpaper is
        // wrong rather than like a system default.
        //
        // Three-button is still the out-of-box setting on a lot of Infinix and
        // Tecno hardware, which is the audience this launcher is for.
        //
        // NOT the XML attribute `android:enforceNavigationBarContrast`. That is
        // API 29+ and declaring it in values/styles.xml would need a values-v29
        // split for one boolean. The guard below is the same decision expressed
        // where the rest of the window setup already lives.
        //
        // Deliberately NOT paired with a manual scrim of our own. The system
        // bar sits over whatever the shell draws there, and every shell already
        // owns that strip: a dock, a panel, or bare wallpaper by choice.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }

        // Lend this Activity to the widget host for the bind/config result flow.
        widgetHost.attachActivity(this)

        // And to the app-list API, which needs one to start the uninstall
        // confirmation. Attached in onCreate rather than onResume so it is
        // already in place for a menu opened during the first frame.
        hostApi.attachActivity(this)
        keysApi.attachActivity(this)

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

        // Back belongs to Dart from the first frame. See [setFrameworkHandlesBack].
        setFrameworkHandlesBack(true)
    }

    /**
     * The host must be listening for its views to receive RemoteViews updates.
     * Tied to start/stop so a backgrounded launcher stops updating hosted
     * widgets, which is the whole reason AppWidgetHost has this pair.
     */
    override fun onStart() {
        if (!installComplete) {
            super.onStart()
            return
        }
        super.onStart()
        widgetHost.startListening()
    }

    override fun onStop() {
        if (!installComplete) {
            super.onStop()
            return
        }
        widgetHost.stopListening()
        super.onStop()
    }

    override fun onDestroy() {
        if (!installComplete) {
            // FlutterActivity calls Activity.onDestroy first and only then
            // detaches a delegate that never attached; the detach is what can
            // throw, and by then the framework has seen its super call.
            try {
                super.onDestroy()
            } catch (_: RuntimeException) {
            }
            return
        }
        // `this`, not a bare call. On a configuration change the replacement
        // Activity's onCreate has ALREADY run, so an unconditional detach here
        // tore down the stage it had just built and every hosted widget
        // vanished for the life of the process. WidgetStage checks the owner.
        WidgetStage.detach(this)
        widgetHost.detachActivity(this)

        // Both detaches are identity-checked on the callee side, which matters
        // on a configuration change: the replacement Activity's onCreate runs
        // BEFORE this, so an unconditional clear here would throw away the
        // reference we were just handed.
        hostApi.detachActivity(this)
        keysApi.detachActivity(this)
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
        // The speech recogniser comes back here too, and unlike the widget
        // flows it needs `data`: the transcript rides in the Intent extras, so
        // a router that drops it would return a successful result with nothing
        // in it. Each handler owns its own request codes and returns false for
        // anything else, so the order of these two lines does not matter today
        // and should stay that way.
        if (hostApi.onActivityResult(requestCode, resultCode, data)) return
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

        // ── WALLPAPER PANNING, FOR THE SAME REASON ──────────────────────────
        //
        // `setWallpaperOffsets` takes a WINDOW TOKEN, and the Pigeon host API
        // holds an application Context. A token comes from a View attached to a
        // window, so this belongs to the Activity exactly as the stage does.
        //
        // The decorView is passed as a LAMBDA rather than a View: this method
        // runs before the window is necessarily laid out, and a token read now
        // would be null. Resolved when a call arrives instead, by which point
        // there is certainly a window because somebody is looking at it.
        WallpaperOffsets.setUp(flutterEngine.dartExecutor.binaryMessenger) {
            if (isFinishing || isDestroyed) null else window?.decorView
        }
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

    // ── BACK ────────────────────────────────────────────────────────────────
    //
    // There is deliberately no onBackPressed override here. There used to be
    // one, and it did nothing but call super, so deleting it changes no
    // behaviour at all while removing the GestureBackNavigation lint error.
    //
    // The behaviour it was documenting is FlutterActivity's own and survives
    // untouched: back sends popRoute over the navigation channel, and if Dart's
    // PopScope refuses, nothing happens. That is exactly "back never leaves the
    // launcher". Nothing here finishes the activity, and nothing should. An
    // override that SWALLOWED back rather than delegating would sever the
    // channel, which is the bug the old comment was warning about.
    //
    // Which mechanism delivers it depends on the platform: below 33 the system
    // calls onBackPressed, and on 33+ the manifest sets
    // enableOnBackInvokedCallback=true so the gesture arrives through
    // FlutterActivity's own OnBackInvokedCallback instead. Both land in the
    // embedding. Overriding here only intercepted the first of the two, which
    // is worse than not overriding: it would have looked like the single place
    // back is handled while being dead code on every modern device.

    /**
     * ALWAYS true. Back on a launcher is never the system's to handle.
     *
     * ─── THE BUG THIS CLOSES ────────────────────────────────────────────────
     *
     * With `enableOnBackInvokedCallback`, FlutterActivity only registers its
     * back callback while the framework says it wants back, and it learns that
     * from route changes. This activity attaches to a CACHED engine that has
     * been running since the process started, so a new or recreated activity
     * can come up having missed that message, with no callback registered. The
     * system then handles back itself, and for an activity its handling is
     * `finish()`: the launcher closed, Android restarted it, and the log said
     * `onStop called after detach` on the way out. It looked like back being
     * broken "throughout the app" because any screen could be the one where the
     * registration had lapsed.
     *
     * Forcing true keeps the callback registered for the life of the activity,
     * so every back reaches Dart's navigator: a pushed screen pops, and on the
     * home the one PopScope in `home_screen.dart` decides. The comment on BACK
     * above still holds: nothing here swallows back, it only stops the system
     * from taking it.
     */
    override fun setFrameworkHandlesBack(frameworkHandlesBack: Boolean) {
        super.setFrameworkHandlesBack(true)
    }

    /**
     * Dart asked to leave the root. A home screen has nothing under it, so the
     * answer is to stay. Returning true says "handled", which stops the
     * embedding from calling `finish()`; returning false is what used to close
     * the launcher on a back press that reached an empty navigator.
     */
    override fun popSystemNavigator(): Boolean = true

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
