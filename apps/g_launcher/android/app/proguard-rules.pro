-dontwarn javax.naming.**
-dontwarn org.bouncycastle.jsse.**
-dontwarn org.bouncycastle.jcajce.provider.**

# Room finds its generated *_Impl classes by reflection off canonicalName, so
# R8 renaming or stripping them fails at first WorkManager touch — which is
# app startup, via androidx.startup.InitializationProvider.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-dontwarn androidx.room.paging.**