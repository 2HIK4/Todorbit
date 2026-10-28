import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.hik4.todorbit"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Development Android identity; preserve this and signing identity for upgrades.
        applicationId = "io.github.hik4.todorbit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Dependencies build additional ABIs. Package only architectures that
        // also receive a Flutter engine for this invocation.
        if (project.findProperty("split-per-abi")?.toString() != "true") {
            val abis = mapOf(
                "android-arm" to "armeabi-v7a",
                "android-arm64" to "arm64-v8a",
                "android-x86" to "x86",
                "android-x64" to "x86_64",
            )
            val targets = project.findProperty("target-platform")?.toString()
                ?.split(',') ?: listOf("android-arm64", "android-x64")
            ndk.abiFilters.addAll(targets.map { abis[it] ?: error("Unsupported Android target: $it") })
        }
    }

    val keyFile = rootProject.file("key.properties")
    val keys = Properties().apply {
        if (keyFile.exists()) keyFile.inputStream().use { load(it) }
    }
    signingConfigs {
        if (keyFile.exists()) create("production") {
            storeFile = file(keys.getProperty("storeFile"))
            storePassword = keys.getProperty("storePassword")
            keyAlias = keys.getProperty("keyAlias")
            keyPassword = keys.getProperty("keyPassword")
        }
    }
    buildTypes {
        release {
            // Production credentials are deliberately separate from debug signing.
            if (keyFile.exists()) signingConfig = signingConfigs.getByName("production")
        }
    }
}

// A release without credentials stays unsigned. Never silently use debug keys.
tasks.configureEach {
    if (name == "validateSigningRelease" && !rootProject.file("key.properties").exists()) {
        doFirst { throw GradleException("Release signing requires android/key.properties and a durable keystore outside Git.") }
    }
}

gradle.taskGraph.whenReady {
    if (allTasks.any { it.name == "assembleRelease" || it.name == "bundleRelease" }) {
        require(rootProject.file("key.properties").exists()) {
            "Production APK/AAB requires android/key.properties. Use a debug build for development."
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
    implementation("com.google.android.gms:play-services-auth:22.0.0")
    implementation("androidx.core:core:1.17.0")
}
