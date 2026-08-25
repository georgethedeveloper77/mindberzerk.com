pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    // START: FlutterFire Configuration
    // 4.5.0, not 4.4.4. The Crashlytics Gradle plugin v3 requires
    // google-services 4.4.1 or newer, and 4.5.0 is what Firebase's own current
    // setup page pairs with 3.0.7.
    id("com.google.gms.google-services") version("4.5.0") apply false
    // The Crashlytics Gradle plugin. WITHOUT IT, R8 mapping files are never
    // uploaded, and this project has `isMinifyEnabled = true` on release: every
    // Kotlin frame in the console is currently unreadable. Dart frames are fine
    // because `--obfuscate` is not passed, which is why the gap was invisible.
    id("com.google.firebase.crashlytics") version("3.0.7") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
