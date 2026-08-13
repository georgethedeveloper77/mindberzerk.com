package com.mindhunter.g_launcher.widgets

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart to [WidgetStage], over a plain MethodChannel.
 *
 * ─── WHY NOT PIGEON, GIVEN EVERYTHING ELSE HERE IS ──────────────────────────
 *
 * The same reason `BadgeBridge` is not, written out in NotificationBadges.kt:
 * the launcher schema's codec numbers its classes, a shipped APK already agrees
 * on those numbers, and every addition is a chance to shift them. This carries
 * three primitive lists and a bool. It needs no class, so it should not take on
 * a codec that has classes in it.
 *
 * It also keeps the change reversible. Nothing generated moves, so backing this
 * out is deleting two files rather than regenerating a schema.
 *
 * ─── THE PLACEMENT WIRE FORMAT ──────────────────────────────────────────────
 *
 * A flat `List<Double>` of five values per widget, not a list of maps. Sync runs
 * on every desktop layout pass, and a map per widget means a HashMap allocation
 * per widget per pass on the platform thread. Five doubles in order costs
 * nothing and the reader is four lines.
 *
 *     [ id, x, y, w, h,  id, x, y, w, h, ... ]
 *
 * Coordinates are dp, global to the screen, measured by Flutter from the tile's
 * own render box. Dp because that is the unit the entire AppWidget API speaks;
 * anything multiplied by devicePixelRatio on the way here tells a provider it
 * has a canvas three times too big, and it inflates the wrong layout at the
 * wrong scale.
 */
class StageBridge private constructor() : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sync" -> {
                val flat = call.argument<List<Double>>("rects") ?: emptyList()
                val visible = call.argument<Boolean>("visible") ?: false

                // Defaults TRUE, which is the behaviour every build before this
                // argument existed had. A missing key means an older Dart
                // bundle against a newer engine, and the desktop taking its own
                // touches is the safe reading of that.
                val interactive = call.argument<Boolean>("interactive") ?: true

                WidgetStage.sync(parse(flat), visible, interactive)
                result.success(null)
            }

            "release" -> {
                val id = call.argument<Int>("widgetId")
                if (id != null) WidgetStage.release(id)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Tolerant of a trailing partial group rather than throwing on one.
     *
     * A malformed list means a Dart bug, and the right response to a Dart bug is
     * a desktop missing one widget, not a platform exception that takes the
     * channel down and leaves every widget frozen where it last was.
     */
    private fun parse(flat: List<Double>): List<WidgetStage.Placement> {
        val out = ArrayList<WidgetStage.Placement>(flat.size / 5)
        var i = 0
        while (i + 4 < flat.size) {
            out += WidgetStage.Placement(
                widgetId = flat[i].toInt(),
                x = flat[i + 1],
                y = flat[i + 2],
                w = flat[i + 3],
                h = flat[i + 4],
            )
            i += 5
        }
        return out
    }

    companion object {
        const val CHANNEL = "g_launcher/widget_stage"

        /// The live channel, kept so native can TALK BACK.
        ///
        /// ─── WHY THIS DIRECTION EXISTS AT ALL ──────────────────────────────
        ///
        /// Everything else here is Dart telling native what to do, which is the
        /// split `WidgetStage` documents: Dart owns every decision, native
        /// obeys. A long press on a hosted widget is the one fact native learns
        /// that Dart cannot, and it cannot learn it for a structural reason
        /// rather than an accidental one.
        ///
        /// `LauncherActivity.dispatchTouchEvent` hands the WHOLE gesture to the
        /// widget the moment a press lands inside one, because a media control
        /// that loses its drag half way through is worse than useless. So
        /// FlutterView never sees the press, no Flutter gesture recogniser ever
        /// fires, and `EditableDesklet`'s long press could not run no matter
        /// how it was written. Hosted tiles were the only tiles on the desktop
        /// with no way to be moved, resized or removed, and the reason was four
        /// lines in an Activity rather than anything about widgets.
        ///
        /// Nulled on teardown so a stale channel is never invoked against a
        /// dead engine.
        private var channel: MethodChannel? = null

        fun setUp(messenger: BinaryMessenger) {
            // REPLACES, per MethodChannel semantics, so a re-registration on an
            // Activity recreate swaps the handler rather than stacking one.
            channel = MethodChannel(messenger, CHANNEL).apply {
                setMethodCallHandler(StageBridge())
            }
        }

        /// The user held [widgetId]. Dart decides what that means.
        ///
        /// Fire and forget: there is no reply worth waiting for, and blocking
        /// the touch path on a round trip to the Dart isolate is how a long
        /// press starts feeling late.
        fun notifyLongPress(widgetId: Int, x: Float, y: Float) {
            channel?.invokeMethod(
                "longPress",
                mapOf(
                    "widgetId" to widgetId,
                    // PIXELS. Dart divides by devicePixelRatio; converting here
                    // would mean native holding an opinion about dp, which is
                    // the split this file's header argues against.
                    "x" to x.toDouble(),
                    "y" to y.toDouble(),
                ),
            )
        }
    }
}
