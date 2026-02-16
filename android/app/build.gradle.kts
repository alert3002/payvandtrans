
import java.util.Properties
import java.io.File
import java.io.FileInputStream

buildscript {
    val kotlin_version = "1.9.23"
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.2.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
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
val flutterVersionCode = (project.findProperty("flutter.versionCode") ?: "18").toString()
val flutterVersionName = (project.findProperty("flutter.versionName") ?: "10.10.10").toString()

android {
    namespace = "com.payvandtrans.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        // Core library desugaring требуется для flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
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
    getByName("debug") {
        // Debug build configuration
        isDebuggable = true
        isMinifyEnabled = false
        isShrinkResources = false
    }
    
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

        // Minification хомуш — барои release APK (гардиш: R8 метавонад APK-ро нест кунад)
        isMinifyEnabled = false
        isShrinkResources = false

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

// Барои Flutter: APK-ро ба ҷойи интизори барнома копия мекунем (барои "couldn't find it")
afterEvaluate {
    val flutterProjectRoot = rootProject.projectDir.parentFile!!
    val apkOutDir = File(flutterProjectRoot, "build/app/outputs/flutter-apk")

    tasks.named("assembleDebug").configure {
        doLast {
            val debugApk = file("$buildDir/outputs/apk/debug/app-debug.apk")
            if (debugApk.exists()) {
                apkOutDir.mkdirs()
                debugApk.copyTo(File(apkOutDir, "app-debug.apk"), overwrite = true)
                println("Copied debug APK to ${File(apkOutDir, "app-debug.apk")}")
            }
        }
    }

    tasks.named("assembleRelease").configure {
        doLast {
            val releaseApk = file("$buildDir/outputs/apk/release/app-release.apk")
            if (releaseApk.exists()) {
                apkOutDir.mkdirs()
                releaseApk.copyTo(File(apkOutDir, "app-release.apk"), overwrite = true)
                println("Copied release APK to ${File(apkOutDir, "app-release.apk")}")
            } else {
                println("WARNING: Release APK not found at $releaseApk")
            }
        }
    }

    val bundleOutDir = File(flutterProjectRoot, "build/app/outputs/bundle/release")
    tasks.named("bundleRelease").configure {
        doLast {
            val releaseAab = file("$buildDir/outputs/bundle/release/app-release.aab")
            if (releaseAab.exists()) {
                bundleOutDir.mkdirs()
                releaseAab.copyTo(File(bundleOutDir, "app-release.aab"), overwrite = true)
                println("Copied release AAB to ${File(bundleOutDir, "app-release.aab")}")
            } else {
                println("WARNING: Release AAB not found at $releaseAab")
            }
        }
    }
}

dependencies {
    // Firebase BOM для управления версиями всех Firebase библиотек
    implementation(platform("com.google.firebase:firebase-bom:34.6.0"))
    
    // Firebase Cloud Messaging
    // firebase-core больше не нужен в новых версиях Firebase (включен автоматически)
    implementation("com.google.firebase:firebase-messaging")
    
    // Core library desugaring для flutter_local_notifications
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
