import com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // AFTER google-services, which is not stylistic: the Crashlytics plugin
    // reads the app id that google-services resolves from google-services.json.
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
    namespace = "com.mindhunter.g_launcher"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mindhunter.g_launcher"

        targetSdk = flutter.targetSdkVersion
        minSdk = flutter.minSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // PHASE C1. AGP only wires up src/test/java by default; the Kotlin plugin
    // adds src/test/kotlin in most configurations but not reliably through the
    // Flutter plugin's ordering. Declaring it is two lines and removes a class
    // of "my tests do not run and nothing says why" — which reads identically
    // to "my tests pass".
    sourceSets {
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    // 1. Define the signing configurations here
    signingConfigs {
        // Create the "release" config only if key.properties actually exists
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
            isMinifyEnabled = false
            isShrinkResources = false
        }

        release {
            // 2. Safe check: assign based on whether we successfully created "release"
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }

            // Turn these to TRUE for production
            isMinifyEnabled = true
            isShrinkResources = true

            // Standard ProGuard rules for Flutter
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
                // A SEPARATE FILE rather than appended to proguard-rules.pro,
                // so what these rules defend against stays documented next to
                // the rules themselves and survives an edit to the other file.
                "proguard-crashlytics.pro"
            )

            // ─── WITHOUT THIS BLOCK THE PLUGIN IS DECORATIVE ───────────────
            //
            // Applying the plugin is not what uploads the mapping file; this
            // is. R8 is on for release, so every class and method name in a
            // Kotlin stack trace is a single letter until the deobfuscation
            // map reaches the console.
            //
            // v3 of the plugin REMOVED the extension from `defaultConfig` and
            // requires it per variant, which is why it is here and not up in
            // the android block. The `mappingFile` field is gone as well; the
            // merged map is provided automatically now.
            configure<CrashlyticsExtension> {
                mappingFileUploadEnabled = true

                // NATIVE SYMBOLS ARE DELIBERATELY LEFT OFF for now. Turning
                // `nativeSymbolUploadEnabled` on also requires
                // `unstrippedNativeLibsDir` pointing at unstripped
                // libflutter.so and libapp.so, plus the
                // firebase-crashlytics-ndk dependency. Half of that
                // arrangement uploads nothing and adds minutes to every
                // release build. It is worth doing on its own, once the
                // memory work has settled, because the Impeller and gralloc
                // failures WidgetStage documents are exactly the class of
                // crash it would catch.
            }
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
    // Wallpaper rotation. WorkManager because the OS must own the schedule —
    // a Timer in Dart dies with the process, and a launcher process gets
    // killed constantly.
    implementation("androidx.work:work-runtime-ktx:2.9.1")

    // PHASE C1 — ed25519 verification of downloaded packs.
    //
    // NOT the platform's Signature.getInstance("Ed25519"): that is API 33+ and
    // this launcher's install base is Infinix/Tecno/Redmi, mostly well below it.
    // BouncyCastle's low-level Ed25519Signer is used DIRECTLY, with no
    // Security.addProvider call — registering a JCE provider fights Conscrypt on
    // several OEM ROMs and fails at the least convenient moment.
    //
    // On size: the artifact is several MB unshrunk, which matters for this
    // audience. R8 is on for release and strips it hard precisely because
    // nothing here touches the provider registry, so the retained set is the
    // ed25519 primitives and their dependencies. Check the size delta after the
    // first release build; if it is unacceptable, net.i2p.crypto:eddsa is ~90KB
    // but unmaintained since 2020, and that is a trade to make deliberately
    // rather than by default.
    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1")

    // ── unit tests (plain JVM, no Robolectric) ───────────────────────────────
    testImplementation("junit:junit:4.13.2")

    // org.json ships with Android but the android.jar on the unit-test
    // classpath is a STUB whose methods throw "not mocked". Without a real
    // implementation here, every PackManifest test fails in a way that looks
    // exactly like a parser bug. This one line is the difference.
    testImplementation("org.json:json:20240303")
}
