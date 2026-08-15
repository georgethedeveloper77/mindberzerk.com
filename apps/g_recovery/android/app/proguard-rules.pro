# jcifs-ng logs through SLF4J and no binding is shipped. SLF4J resolves its
# binder reflectively at runtime and falls back to a no-op when none is found,
# so the class genuinely is not needed. R8 cannot know that, so tell it.
-dontwarn org.slf4j.**
-dontwarn javax.servlet.**

# jcifs-ng reads its configuration by reflection over property names, and R8
# renames the fields it looks for. Without this, SMB fails at runtime with a
# config error that looks nothing like an obfuscation problem.
-keep class jcifs.** { *; }
-keep interface jcifs.** { *; }
-dontwarn jcifs.**

# Room builds its database by reflecting on <DatabaseClass>_Impl and calling a
# no-arg constructor that nothing in the source ever calls. R8 full mode removes
# it as dead code, and the failure is at startup, in a content provider, before
# any of this app's code runs.
#
# Only Room 2.6.1 needs this stated by hand. It arrives transitively through
# work-runtime-ktx 2.10.0 and is the last release before Room began shipping its
# own consumer rules, so the rule goes when that dependency next moves.
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public <init>();
}
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# WorkManager stores a worker as its CLASS NAME, in the database, and rebuilds
# it by reflection when the job is due.
#
# R8 renames the class, the stored name no longer resolves, and the worker fails
# to instantiate. The failure lands on a schedule rather than on a tap, so the
# first sign of it is a backup that did not happen overnight with nothing on
# screen to explain why.
#
# work-runtime ships equivalent rules of its own and they have been correct for
# several releases. This is stated anyway because the cost is nothing and the
# thing it protects is the feature the whole app is being repositioned around.
-keep public class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
