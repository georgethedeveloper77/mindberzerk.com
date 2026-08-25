# Rules Crashlytics needs once R8 is on. Referenced from the release build type
# in build.gradle.kts, alongside proguard-rules.pro.
#
# Kept in its own file rather than appended to proguard-rules.pro so that what
# each rule defends against stays written next to the rule, and so an edit to
# the Flutter rules cannot quietly drop these.

# ─── READABLE STACK TRACES ───────────────────────────────────────────────────
#
# Without SourceFile and LineNumberTable, an uploaded mapping file can restore
# class and method names but has no line to point at, so every frame resolves to
# the method with no offset. Renaming SourceFile to a constant is the standard
# pairing: it keeps the original filename out of the APK while leaving the
# mapping able to put it back.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Exception subclasses are matched by NAME in the console. `_ProcessKilled` and
# `_MainIsolateStall` are Dart types and unaffected, but anything thrown from
# Kotlin groups by its obfuscated name without this.
-keepattributes *Annotation*
-keepattributes Signature

# ─── AGP 9 STRICT FULL MODE ──────────────────────────────────────────────────
#
# AGP 9 turns `android.r8.strictFullModeForKeepRules` on by default, and this
# project is on AGP 9.0.1. Firebase discovers its components through
# ComponentRegistrar implementations named in the manifest and instantiated
# reflectively, which strict full mode no longer keeps on the strength of the
# manifest reference alone.
#
# The symptom if these are missing is not a missing report. It is a RELEASE-ONLY
# hard crash at process start:
#
#   java.lang.RuntimeException: Unable to create application <MyApp>
#   Caused by: java.lang.NullPointerException:
#       FirebaseCrashlytics component is not present
#
# On the home app that is an unbootable desktop, and it does not reproduce in
# debug, which is the worst possible shape for it to have. See
# firebase/firebase-android-sdk#7367.
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    <init>();
}
-keepnames class com.google.firebase.components.ComponentRegistrar

# The Crashlytics build tooling reads these back off the APK.
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**
