# GoBackend reaches into these classes from native code through JNI. R8 cannot
# see those references and would strip or rename them, which fails only in
# release builds, at connect time.
-keep class com.wireguard.android.backend.** { *; }
-keep class com.wireguard.crypto.** { *; }
-keep class com.wireguard.config.** { *; }
