plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore config from key.properties (local) or environment variables (CI).
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

fun String?.orEnv(key: String): String? = this?.takeIf { it.isNotEmpty() } ?: System.getenv(key)

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
            storeFile = keystoreProperties["storeFile"]
                ?.toString()?.takeIf { it.isNotEmpty() }?.let { file(it) }
                ?: System.getenv("KEYSTORE_PATH")?.let { file(it) }

            storePassword = keystoreProperties["storePassword"]?.orEnv("KEYSTORE_PASSWORD")
            keyAlias = keystoreProperties["keyAlias"]?.orEnv("KEY_ALIAS")
            keyPassword = keystoreProperties["keyPassword"]?.orEnv("KEY_PASSWORD")
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
