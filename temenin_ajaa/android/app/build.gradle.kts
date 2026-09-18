plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import java.io.File

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

// Read API Key from local.properties or .env in project root
var mapsKey = localProperties.getProperty("GOOGLE_MAPS_API_KEY") ?: localProperties.getProperty("MAPS_API_KEY") ?: ""
if (mapsKey.isEmpty()) {
    val envFile = File(rootDir.parentFile, ".env")
    if (envFile.exists()) {
        envFile.forEachLine { line ->
            val trimmed = line.trim()
            if (trimmed.startsWith("GOOGLE_MAPS_API_KEY=")) {
                mapsKey = trimmed.substringAfter("GOOGLE_MAPS_API_KEY=").trim().trim('"', '\'')
            }
        }
    }
}
if (mapsKey.isEmpty()) {
    mapsKey = System.getenv("GOOGLE_MAPS_API_KEY") ?: ""
}

android {
    namespace = "com.example.temenin_ajaa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.temenin_ajaa"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
