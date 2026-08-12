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