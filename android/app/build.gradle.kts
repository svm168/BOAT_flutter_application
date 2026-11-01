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

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
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

    applicationVariants.all {
        outputs.all {
            // Kotlin DSL requires explicit casting to access outputFileName
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            if (output.outputFileName.endsWith(".apk")) {
                // Safely read the version from Flutter's local properties
                val versionName = localProperties.getProperty("flutter.versionName") ?: "1.0.0"
                output.outputFileName = "BOAT_v${versionName}.apk"
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
