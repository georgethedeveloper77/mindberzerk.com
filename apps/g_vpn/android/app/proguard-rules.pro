# GoBackend reaches into these classes from native code through JNI. R8 cannot
# see those references and would strip or rename them, which fails only in
# release builds, at connect time.
-keep class com.wireguard.android.backend.** { *; }
-keep class com.wireguard.crypto.** { *; }
-keep class com.wireguard.config.** { *; }

# Room creates each generated *_Impl database through its no-arg constructor by
# reflection. Room 2.6.1's consumer rule keeps the class but not its members,
# so R8 full mode strips WorkDatabase_Impl.<init>() and WorkManager crashes
# at process start (InitializationProvider). Release builds only.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
