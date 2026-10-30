package com.mindhunter.g_launcher

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Shown instead of the launcher when this install is missing its native code.
 *
 * ─── WHAT THIS IS FOR ───────────────────────────────────────────────────────
 *
 * Crashlytics on 6.0.0: `Could not find 'libflutter.so'. Looked for:
 * [arm64-v8a, armeabi-v7a, armeabi], but only found: []`, thrown from
 * [LauncherApplication.onCreate] the moment it built the engine. Play ships
 * the native libraries in a separate split APK; a copy passed around as one
 * base APK (an "APK sharing" app, a backup restore) installs without it, and
 * nothing in Flutter can run.
 *
 * For an ordinary app that is one crash. For a HOME app it is a crash every
 * time the user presses home, which is a phone that feels broken. So the
 * launcher checks for the library first and, when it is missing, lands here:
 * plain Android views, no Flutter, two ways out.
 *
 * Not translated through the Flutter i18n files, because Flutter is exactly
 * what is missing. The strings live in res/values like any native screen.
 */
class BrokenInstallActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val pad = dp(24)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(pad, pad, pad, pad)
            setBackgroundColor(Color.BLACK)
        }

        root.addView(text(getString(R.string.broken_install_title), 22f, bold = true))
        root.addView(spacer(12))
        root.addView(text(getString(R.string.broken_install_body), 15f, muted = true))
        root.addView(spacer(28))
        root.addView(
            button(getString(R.string.broken_install_reinstall), primary = true) {
                openPlay()
            },
        )
        root.addView(spacer(12))
        root.addView(
            button(getString(R.string.broken_install_other_home), primary = false) {
                openHomeSettings()
            },
        )

        setContentView(root)
    }

    /** The Play listing, in the Play app when there is one, else the web. */
    private fun openPlay() {
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName"))
        try {
            startActivity(market)
        } catch (_: ActivityNotFoundException) {
            startActivity(
                Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=$packageName"),
                ),
            )
        }
    }

    /** Android's own default-home picker, so the phone has a working home now. */
    private fun openHomeSettings() {
        try {
            startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
        } catch (_: ActivityNotFoundException) {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }

    private fun dp(v: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        v.toFloat(),
        resources.displayMetrics,
    ).toInt()

    private fun spacer(h: Int) = android.view.View(this).apply {
        layoutParams = LinearLayout.LayoutParams(1, dp(h))
    }

    private fun text(value: String, size: Float, bold: Boolean = false, muted: Boolean = false) =
        TextView(this).apply {
            text = value
            textSize = size
            gravity = Gravity.CENTER
            setTextColor(if (muted) 0xB3FFFFFF.toInt() else Color.WHITE)
            if (bold) setTypeface(typeface, android.graphics.Typeface.BOLD)
        }

    /** A 48dp-tall rounded button, full width. */
    private fun button(label: String, primary: Boolean, onClick: () -> Unit) =
        Button(this).apply {
            text = label
            isAllCaps = false
            textSize = 16f
            minHeight = dp(48)
            setTextColor(if (primary) Color.WHITE else 0xFF4C8DFF.toInt())
            background = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(if (primary) 0xFF4C8DFF.toInt() else 0x22FFFFFF)
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            setOnClickListener { onClick() }
        }
}
