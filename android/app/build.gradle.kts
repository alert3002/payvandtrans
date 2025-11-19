// Файли: android/app/build.gradle.kts (Версияи пурраи ислоҳшуда)

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

// === ҚИСМИ 1: Ин код файли key.properties-ро мехонад ===
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// =======================================================

val localProps = localProperties()
val flutterVersionCode = (project.findProperty("flutter.versionCode") ?: "3").toString()
val flutterVersionName = (project.findProperty("flutter.versionName") ?: "1.0.3").toString()

android {
    namespace = "com.payvandtrans.app"
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
        applicationId = "com.payvandtrans.app"
        minSdk = 26
        targetSdk = 34
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    // === ҚИСМИ 2: Ин блок конфигуратсияи имзоро эҷод мекунад ===
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val keyAliasProp = keystoreProperties.getProperty("keyAlias")
                val keyPasswordProp = keystoreProperties.getProperty("keyPassword")
                val storeFileProp = keystoreProperties.getProperty("storeFile")
                val storePasswordProp = keystoreProperties.getProperty("storePassword")
                
                if (keyAliasProp != null && keyPasswordProp != null && storeFileProp != null && storePasswordProp != null) {
                    keyAlias = keyAliasProp
                    keyPassword = keyPasswordProp
                    storeFile = file(storeFileProp)
                    storePassword = storePasswordProp
                }
            }
        }
    }
    // ==========================================================

    buildTypes {
        getByName("release") {
            // === ҚИСМИ 3: Ин сатр конфигуратсияи имзоро истифода мебарад ===
            // Only use signing config if key.properties exists and has valid properties
            val keystoreFile = keystoreProperties.getProperty("storeFile")
            if (keystorePropertiesFile.exists() && keystoreFile != null && file(keystoreFile).exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // ==============================================================

            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Ин сатрро нест кардан ё коммент кардан мумкин аст, зеро мо дигар аз Yandex истифода намебарем
    // implementation("com.yandex.android:maps.mobile:4.5.1-lite")
}