import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // AFTER google-services: Crashlytics reads the app id it resolves.
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    // The LIVE Play package. Changing it publishes a new app instead of an
    // update to the existing listing.
    namespace = "com.mindberzerk.gvpn"

    // Android 16 (API 36): what Play requires of every update since
    // 31 August 2026. Pinned rather than taken from Flutter's defaults so a
    // Flutter upgrade cannot quietly move it.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mindberzerk.gvpn"
        targetSdk = 36
        // Android 7.0. WireGuard and the OpenVPN engine both run from here.
        minSdk = 24
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Without this the plugin uploads nothing and every Kotlin frame
            // in a release crash is a single obfuscated letter.
            configure<CrashlyticsExtension> {
                mappingFileUploadEnabled = true
            }
        }
    }

    // Extract native libraries on install. OpenVPN runs as a native
    // executable shipped as libovpnexec.so, which only works as a real file
    // on disk; wireguard-go's libraries load fine either way.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // The official WireGuard Android tunnel library (Apache 2.0): GoBackend,
    // its VpnService, and the wg-quick config parser. This replaces the
    // template's OneConnect SDK and OpenVPN engine entirely.
    implementation("com.wireguard.android:tunnel:1.0.20260102")

    // QR import. Google's code scanner runs INSIDE Play services and hands
    // back only the decoded text, so this app needs no CAMERA permission and
    // ships no camera code. The scanner module downloads on first use.
    implementation("com.google.android.gms:play-services-code-scanner:16.1.0")
    // QR codes in saved images ("From an image", shares from other apps),
    // read on the phone. The Play services build keeps the APK small.
    implementation("com.google.android.gms:play-services-mlkit-barcode-scanning:18.3.1")

    // OpenVPN engine: OpenVPN for Android (GPLv2), built from source by
    // android/openvpn/build-aar.sh. The .aar carries no dependency metadata,
    // so its two runtime needs are listed here.
    implementation(files("libs/ics-openvpn.aar"))
    implementation("androidx.annotation:annotation:1.9.1")
    implementation("androidx.core:core:1.15.0")

    // SSTP engine (Open SSTP Client, MIT), compiled from source in
    // src/main/kotlin/kittoku/osc. Its three runtime needs:
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("androidx.preference:preference-ktx:1.2.1")
    implementation("androidx.documentfile:documentfile:1.1.0")
}
