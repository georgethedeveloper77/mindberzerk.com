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
