import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun localProperties(): Properties {
    val properties = Properties()
    val localPropertiesFile = project.rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        properties.load(FileInputStream(localPropertiesFile))
    }
    return properties
}

val localProps = localProperties()
val flutterVersionCode = localProps.getProperty("flutter.versionCode")
val flutterVersionName = localProps.getProperty("flutter.versionName")
android {
    namespace = "com.example.my_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.example.my_app"
        minSdk = 26
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    buildTypes {
    getByName("release") {
        signingConfig = signingConfigs.getByName("debug")

        // --- САТРҲОИ ИЛОВАШУДА ---
        // R8 (minification)-ро фаъол мекунад
        isMinifyEnabled = true

        // Файлҳои қоидаҳоро нишон медиҳад
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
        // -------------------------
    }
}
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.yandex.android:maps.mobile:4.5.1-lite")
}