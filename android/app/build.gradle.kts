plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.boat.tracker.boat_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.boat.tracker.boat_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all { variant ->
        variant.outputs.all { output ->
            // Ensure we are only renaming the APK file
            if (output.outputFileName != null && output.outputFileName.endsWith('.apk')) {
                // flutterVersionName is defined at the top of this gradle file by default in Flutter
                output.outputFileName = "BOAT_v${flutterVersionName}.apk" 
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.altbeacon:android-beacon-library:2.20.1")
    implementation("com.google.android.gms:play-services-location:21.2.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
