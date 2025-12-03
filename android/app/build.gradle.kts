// Файли: android/app/build.gradle.kts (Версияи пурраи ислоҳшуда)
// Ин файл барои сохтмони муваффақ дар маҳаллӣ (бо key.properties) ва дар Codemagic (бо Environment Variables) танзим шудааст.

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

// === ҚИСМИ 1: Ин код файли key.properties-ро мехонад (Масири ислоҳшуда) ===
val keystoreProperties = Properties()
// Файл key.properties дар решаи лоиҳаи Gradle (`android/`) ҷойгир аст
val keystorePropertiesFile = rootProject.file("key.properties") 
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// =======================================================

val localProps = localProperties()
// Боварӣ ҳосил кунед, ки version code ва version name дуруст муайян шудаанд
// Поёнӣ як арзиши пешфарзро таъмин мекунад; Play Console ба шумо талаб мекунад версияҳои навро яхд карда
// барои интишор — инро ба 5 бадахшам (requested by Play Console).
val flutterVersionCode = (project.findProperty("flutter.versionCode") ?: "7").toString()
val flutterVersionName = (project.findProperty("flutter.versionName") ?: "1.0.1").toString()

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
        targetSdk = 35
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    // === ҚИСМИ 2: Ин блок конфигуратсияи имзоро эҷод мекунад ===
    signingConfigs {
    create("release") {
        // Арзишҳоро мустақиман аз key.properties мехонем
        val keystorePath = keystoreProperties.getProperty("storeFile") ?: ""
        if (keystorePath.isNotEmpty()) {
            // Агар масир нисбӣ аст, онро нисбӣ ба rootProject муайян мекунем
            val keystoreFile = if (keystorePath.startsWith("/") || keystorePath.contains(":")) {
                file(keystorePath)
            } else {
                rootProject.file(keystorePath)
            }
            storeFile = keystoreFile
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }
}
    // ==========================================================

    buildTypes {
    getByName("release") {
        // === ҚИСМИ 3: Пайваст кардани конфигуратсияи имзокунии release ===
        val keystorePath = keystoreProperties.getProperty("storeFile") ?: ""
        
        if (keystorePath.isNotEmpty()) {
            val keystoreFile = if (keystorePath.startsWith("/") || keystorePath.contains(":")) {
                file(keystorePath)
            } else {
                rootProject.file(keystorePath)
            }
            
            // Танҳо агар файли Keystore воқеан мавҷуд бошад, Release Signing-ро истифода баред
            if (keystoreFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
                println("INFO: Release signing configuration successfully applied. Keystore: ${keystoreFile.absolutePath}")
            } else {
                println("WARNING: Release signing skipped. Keystore file not found at: ${keystoreFile.absolutePath}")
            }
        } else {
            println("WARNING: Release signing skipped. Keystore path is empty in key.properties")
        }

        // Барои тест кардан, минфикатсияро хомуш карда метавонем
        // Агар хатоги боқӣ монд, инро ба true баргардонед
        isMinifyEnabled = true
        isShrinkResources = true

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

}
