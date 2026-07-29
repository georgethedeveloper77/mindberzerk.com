-dontwarn javax.naming.**
-dontwarn org.bouncycastle.jsse.**
-dontwarn org.bouncycastle.jcajce.provider.**

# Room finds its generated *_Impl classes by reflection off canonicalName, so
# R8 renaming or stripping them fails at first WorkManager touch — which is
# app startup, via androidx.startup.InitializationProvider.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-dontwarn androidx.room.paging.**
# WorkManager instantiates workers BY NAME from a string in its own database, so
# a renamed class throws at execution time on a background thread with nothing
# in the UI to show for it. work-runtime's consumer rules keep `extends Worker`;
# CoroutineWorker is a ListenableWorker and is not covered by that.
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context, androidx.work.WorkerParameters);
}