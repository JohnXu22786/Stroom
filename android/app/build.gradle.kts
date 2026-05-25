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
    val v = keystoreProps.getProperty(key)
    if (v != null && v.isNotEmpty()) return v
    return System.getenv(env) ?: ""
}

android {
    namespace = "com.johntsui.stroom"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
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
    }

    signingConfigs {
        create("release") {
            val sf = prop("storeFile", "KEYSTORE_PATH")
            if (sf.isNotEmpty()) storeFile = file(sf)
            storePassword = prop("storePassword", "KEYSTORE_PASSWORD")
            keyAlias = prop("keyAlias", "KEY_ALIAS")
            keyPassword = prop("keyPassword", "KEY_PASSWORD")
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
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.1.0")
}

flutter {
    source = "../.."
}
