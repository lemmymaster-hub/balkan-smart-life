plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.android.libraries.mapsplatform.secrets-gradle-plugin")
}

val releaseKeystorePath =
    System.getenv("BSL_RELEASE_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }
val releasePassword =
    System.getenv("BSL_RELEASE_PASSWORD")?.takeIf { it.isNotBlank() }
val releaseSigningConfigured = releaseKeystorePath != null && releasePassword != null
val releaseBuildRequested =
    gradle.startParameter.taskNames.any { taskName ->
        taskName.contains("release", ignoreCase = true)
    }

if (releaseBuildRequested && !releaseSigningConfigured) {
    throw GradleException(
        "Release signing is mandatory. Set BSL_RELEASE_KEYSTORE_PATH and " +
            "BSL_RELEASE_PASSWORD before building a release APK.",
    )
}

if (releaseSigningConfigured && !file(releaseKeystorePath!!).isFile) {
    throw GradleException("Release keystore was not found at BSL_RELEASE_KEYSTORE_PATH.")
}

android {
    namespace = "ba.balkansmartlife.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ba.balkansmartlife.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releasePassword
                keyAlias = "bsl-release"
                keyPassword = releasePassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
}

secrets {
    defaultPropertiesFileName = "local.defaults.properties"
}
