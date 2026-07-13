plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProps = Properties()
val keystorePropsFile = rootProject.file("key.properties")
if (keystorePropsFile.exists()) {
    keystoreProps.load(FileInputStream(keystorePropsFile))
}

fun prop(key: String, env: String): String {
    val envValue = System.getenv(env)
    if (envValue != null && envValue.isNotEmpty()) return envValue
    val v = keystoreProps.getProperty(key)
    if (v != null && v.isNotEmpty()) return v
    return ""
}

android {
    namespace = "com.johntsui.stroom"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.johntsui.stroom"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        ndk {
            abiFilters.clear()
            abiFilters.add("arm64-v8a")
        }
    }

    signingConfigs {
        create("release") {
            val sf = prop("storeFile", "KEYSTORE_PATH")
            if (sf.isNotEmpty() && file(sf).exists()) {
                storeFile = file(sf)
                storePassword = prop("storePassword", "KEYSTORE_PASSWORD")
                keyAlias = prop("keyAlias", "KEY_ALIAS")
                keyPassword = prop("keyPassword", "KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            lint {
                checkReleaseBuilds = false
                abortOnError = false
            }
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            val hasStore = signingConfigs.getByName("release").storeFile != null
            if (hasStore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:2.1.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // SAF (Storage Access Framework) 支持
    implementation("androidx.documentfile:documentfile:1.0.1")
    // Activity Result API (registerForActivityResult)
    implementation("androidx.activity:activity-ktx:1.9.3")
}

flutter {
    source = "../.."
}
