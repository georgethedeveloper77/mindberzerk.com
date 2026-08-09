plugins {
    // com.android.library ONLY.
    //
    // No org.jetbrains.kotlin.android here. AGP 9 ships Built-in Kotlin, and a
    // plugin package that applies KGP itself triggers Flutter's warning that
    // future versions will fail to build. apps/g_recovery/android/app/build.
    // gradle.kts applies no KGP either, so this now matches the app exactly.
    id("com.android.library")
}

// extensions.configure rather than a bare `android { }` block.
//
// AGP 9 defaults to android.newDsl=true, under which the generated `android { }`
// accessor for a LIBRARY still resolves to the legacy
// com.android.build.gradle.LibraryExtension, and that resolution is a hard error
// rather than a warning. Naming com.android.build.api.dsl.LibraryExtension
// explicitly is the migration path and also works on AGP 8, where both exist.
extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
    namespace = "com.mindberzerk.device_probe"

    // The app resolves this from `flutter.compileSdkVersion`, which the Flutter
    // Gradle plugin provides. That plugin is applied to the app module only, so
    // a plugin package has to name a number. Keep it equal to whatever the app
    // resolves to: a library compiled against a HIGHER sdk than its consumer is
    // an error, and a lower one silently hides newer API.
    compileSdk = 36

    defaultConfig {
        // Deliberately far below the app's floor of 30. Manifest merger takes
        // the MAXIMUM of app and library, so a low library minSdk can never
        // raise the app's, while a high one would silently drop devices. Every
        // API above 21 used in this package is guarded at the call site.
        minSdk = 21
    }

    compileOptions {
        // 17, matching the app. Under Built-in Kotlin the module is compiled as
        // part of one build with a shared toolchain, so a lower target here buys
        // nothing and risks an inconsistent JVM target error.
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// Same shape as the app's, and the replacement for the deprecated
// `kotlinOptions { }` block that AGP 9 rejects.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
