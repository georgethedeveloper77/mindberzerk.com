package com.mindberzerk.device_probe

import android.content.Context
import android.os.Build
import android.provider.Settings

/**
 * WHICH PHONE THIS IS, in the words its owner would use.
 *
 * ─── THE PROBLEM ─────────────────────────────────────────────────────────────
 *
 * There is no Android API for the name on the box. `Build.MODEL` gives
 * `SM-S906E`, `Build.DEVICE` gives `g0q`, and `Build.PRODUCT` gives
 * `g0qzcx`. All three are correct and none of them is what the owner calls it.
 *
 * Every OEM solved this privately. Transsion, Xiaomi, Realme and OnePlus set a
 * marketing name system property. Huawei sets a different one. Samsung, which
 * is the largest single manufacturer in this app's market, sets NEITHER, and
 * keeps the readable name in Settings.Global instead.
 *
 * So the resolution is a ladder, tried in order, and the rung that answers
 * first wins.
 *
 * ─── THE SETTINGS RUNG IS USER EDITABLE ──────────────────────────────────────
 *
 * `device_name` defaults to the marketing name on Samsung, which is exactly
 * what is wanted. It is also the field Settings exposes as "Device name", so a
 * phone someone renamed reports the new string. That is usually an improvement,
 * since a person who renamed their phone recognises the new name faster than
 * the old one, but it means this value is not a stable identifier and must
 * never be treated as one.
 *
 * ─── REFLECTION, AND WHY IT IS SAFE HERE ─────────────────────────────────────
 *
 * `android.os.SystemProperties` is not public API. It is read by reflection
 * because there is no alternative, and every failure path returns null: a
 * blocked reflective call, a missing class, a missing method and an absent
 * property are all simply "this rung did not answer", and the ladder continues.
 * Nothing here throws, and nothing here is required for the object to be built.
 */
internal class IdentityProbe(context: Context) {

    private val app: Context = context.applicationContext

    fun read(): DeviceIdentity = DeviceIdentity(
        marketingName = marketingName(),
        manufacturer = Build.MANUFACTURER ?: Build.UNKNOWN,
        model = Build.MODEL ?: Build.UNKNOWN,
        androidRelease = Build.VERSION.RELEASE ?: Build.UNKNOWN,
        sdkInt = Build.VERSION.SDK_INT.toLong(),
        securityPatch = if (Build.VERSION.SDK_INT >= 23) {
            Build.VERSION.SECURITY_PATCH?.takeIf { it.isNotBlank() }
        } else {
            null
        },
        skin = skin(),
        fingerprint = Build.FINGERPRINT ?: Build.UNKNOWN,
    )

    /**
     * The ladder. Vendor properties first because they are the manufacturer's
     * own answer and cannot have been edited by the user, then the system
     * device name, then nothing.
     *
     * Returning null rather than falling back to MANUFACTURER plus MODEL is
     * deliberate: the caller has both of those fields already and can decide how
     * to present them. Composing a fallback here would hide from the UI whether
     * a real name was ever found.
     */
    private fun marketingName(): String? {
        val fromVendor = MARKETING_KEYS.firstNotNullOfOrNull { prop(it) }
        if (fromVendor != null) return fromVendor

        val fromSettings = try {
            Settings.Global.getString(app.contentResolver, "device_name")
        } catch (_: Throwable) {
            null
        }
        return fromSettings?.trim()?.takeIf { it.isNotBlank() }
    }

    /**
     * The OEM layer, where the ROM admits to having one.
     *
     * One UI encodes its version as a packed integer: 60101 is 6.1. Everything
     * else reports a string already fit to display, so it is passed through
     * untouched rather than parsed into a shape this code would have to keep
     * guessing at.
     *
     * An unrecognised skin returns null. A device running something not on this
     * list is not thereby broken, and inventing a label for it would put a
     * wrong string on the identity card forever.
     */
    private fun skin(): String? {
        prop("ro.build.version.oneui")?.toIntOrNull()?.let { packed ->
            val major = packed / 10000
            val minor = (packed / 100) % 100
            return if (major > 0) "One UI $major.$minor" else null
        }
        prop("ro.mi.os.version.name")?.let { return it }
        prop("ro.miui.ui.version.name")?.let { return "MIUI ${it.removePrefix("V")}" }
        prop("ro.tranos.version")?.let { return it }
        prop("ro.build.version.emui")?.let { return it }
        prop("ro.build.version.opporom")?.let { return "ColorOS ${it.removePrefix("V")}" }
        prop("ro.vivo.os.version")?.let { return "Funtouch $it" }
        return null
    }

    private fun prop(key: String): String? = try {
        val cls = Class.forName("android.os.SystemProperties")
        val get = cls.getMethod("get", String::class.java)
        (get.invoke(null, key) as? String)
            ?.trim()
            ?.takeIf { it.isNotBlank() && it != Build.UNKNOWN }
    } catch (_: Throwable) {
        null
    }

    private companion object {
        /**
         * Order matters. `ro.product.marketname` is the most widely set, and the
         * vendor-prefixed variant is what survives on devices where the system
         * partition was trimmed.
         */
        val MARKETING_KEYS = listOf(
            "ro.product.marketname",
            "ro.vendor.product.marketname",
            "ro.product.vendor.marketname",
            "ro.config.marketing_name",
            "ro.product.odm.marketname",
        )
    }
}
