// Файли android/build.gradle.kts
// ТАМОМИ МАЗМУНИ ФАЙЛИ ХУДРО БО ИН КОД ИВАЗ КУНЕД

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

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            this.url = uri("https://maven.yandex.ru/repository/yandex/")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
