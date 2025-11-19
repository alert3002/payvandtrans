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
            // Аввал кӯшиш мекунад, ки аз environment variables (Codemagic) истифода барад
            val keystorePath = System.getenv("CM_KEYSTORE_PATH") ?: keystoreProperties.getProperty("storeFile")
            val keystorePassword = System.getenv("CM_KEYSTORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")
            val keyAliasProp = System.getenv("CM_KEY_ALIAS") ?: keystoreProperties.getProperty("keyAlias")
            val keyPasswordProp = System.getenv("CM_KEY_PASSWORD") ?: keystoreProperties.getProperty("keyPassword")
            
            if (keystorePath != null && keystorePassword != null && keyAliasProp != null && keyPasswordProp != null) {
                val keystoreFile = file(keystorePath)
                if (keystoreFile.exists()) {
                    keyAlias = keyAliasProp
                    keyPassword = keyPasswordProp
                    storeFile = keystoreFile
                    storePassword = keystorePassword
                }
            }
        }
    }
    // ==========================================================

    buildTypes {
        getByName("release") {
            // Барои Codemagic: агар release signing мавҷуд набошад, аз debug signing истифода мекунад
            val releaseSigning = signingConfigs.findByName("release")
            signingConfig = if (releaseSigning != null && releaseSigning.storeFile != null && releaseSigning.storeFile!!.exists()) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }

            // Барои тафтиш: minify ва shrink-ро ғайрифаъол кардем
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    // Таъмини сохтани bundle файл
    bundle {
        language {
            enableSplit = false
        }
        density {
            enableSplit = false
        }
        abi {
            enableSplit = false
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

// Вазъияти файли bundle-ро пас аз сохт тафтиш мекунад
afterEvaluate {
    tasks.named("bundleRelease") {
        doLast {
            val bundleDir = file("${project.buildDir}/outputs/bundle/release")
            val bundleFile = file("${bundleDir}/app-release.aab")
            
            println("=== Bundle File Check ===")
            println("Bundle directory: ${bundleDir.absolutePath}")
            println("Bundle file exists: ${bundleFile.exists()}")
            if (bundleFile.exists()) {
                println("Bundle file size: ${bundleFile.length()} bytes")
                println("Bundle file path: ${bundleFile.absolutePath}")
            } else {
                println("ERROR: Bundle file not found!")
                println("Listing files in bundle directory:")
                if (bundleDir.exists()) {
                    bundleDir.listFiles()?.forEach { file ->
                        println("  - ${file.name} (${file.length()} bytes)")
                    }
                } else {
                    println("  Bundle directory does not exist!")
                }
            }
            println("========================")
        }
    }
}