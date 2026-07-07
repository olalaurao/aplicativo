plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.productivity.quartzo"
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
        applicationId = "com.productivity.citrine"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        ndk {
        abiFilters += listOf("arm64-v8a")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
flutter {
    source = "../.."
}

// Workaround: Flutter Gradle plugin sets fileMode = 0644 (POSIX) on asset copy tasks,
// which fails on Windows. This removes the fileMode setting after the plugin configures
// the tasks so the build can complete successfully on Windows.
if (org.gradle.internal.os.OperatingSystem.current().isWindows) {
    afterEvaluate {
        tasks.withType<Copy>().configureEach {
            filePermissions { }
            dirPermissions { }
        }
    }
}
