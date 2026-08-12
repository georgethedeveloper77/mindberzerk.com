import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.mindhunter.g_recovery"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // CORE LIBRARY DESUGARING, and it arrives with the minSdk drop below.
        //
        // BouncyCastle's bcprov-jdk18on is built for a full JDK 8 library and
        // reaches for pieces of it that Android did not carry until later.
        // Above API 30 that never showed; at 24 a missing desugared class
        // surfaces during verification, and Ed25519 failing to load looks
        // EXACTLY like a signature that did not verify. That is a day lost to a
        // symptom pointing at the wrong subsystem.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Locked. Changing this orphans the live listing and its install base.
        applicationId = "com.mindhunter.g_recovery"

        minSdk = 24

        targetSdk = flutter.targetSdkVersion
        // Both read from the pubspec version, currently 2.0.0+7.
        // Live on Play is versionCode 6, versionName 1.0.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storePassword = keystoreProperties.getProperty("storePassword")
            keystoreProperties.getProperty("storeFile")?.let { storeFile = file(it) }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (keystorePropertiesFile.exists()) "release" else "debug"
            )
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {

    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1")

    // Pairs with `isCoreLibraryDesugaringEnabled` above. Bump if AGP asks for a
    // newer one; it names the required version in the failure.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
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
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("eu.agno3.jcifs:jcifs-ng:2.1.10")
    implementation("androidx.work:work-runtime-ktx:2.10.0")
    implementation("androidx.exifinterface:exifinterface:1.4.1")

    // WebDAV, and the only reason it needs a library at all.
    //
    // HttpURLConnection checks the method name against a fixed list and throws
    // on PROPFIND, which WebDAV cannot do without. The workaround people reach
    // for is reflection into a private field of the platform class, and a
    // backup path is the last place to put something that breaks on an OS
    // update.
    //
    // 4.12.0 rather than 5.x on purpose: 5.x raises the minimum to API 21 with
    // a different Kotlin baseline and pulls okio 3, and none of the WebDAV work
    // here uses anything 5.x added.
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Video re-encoding.
    //
    // Transformer rather than MediaCodec directly. Doing this by hand means
    // owning muxing, timestamp handling, audio passthrough and one decoder quirk
    // per chipset, and getting any of it slightly wrong produces a file that
    // plays on the phone that made it and nowhere else.
    //
    // The -common and -transformer split is deliberate: the full media3 bundle
    // pulls ExoPlayer and a UI module this app has no player for.
    implementation("androidx.media3:media3-transformer:1.4.1")
    implementation("androidx.media3:media3-effect:1.4.1")
    implementation("androidx.media3:media3-common:1.4.1")
}