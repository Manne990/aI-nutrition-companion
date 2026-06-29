import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val androidApplicationId =
    providers.gradleProperty("AI_NUTRITION_ANDROID_APPLICATION_ID").orNull
        ?: System.getenv("AI_NUTRITION_ANDROID_APPLICATION_ID")
        ?: "app.ainutrition.companion"

val releaseKeystoreProperties = Properties()
val releaseKeystorePropertiesFile = rootProject.file("key.properties")
if (releaseKeystorePropertiesFile.exists()) {
    releaseKeystorePropertiesFile.inputStream().use { releaseKeystoreProperties.load(it) }
}

fun releaseSigningValue(propertyName: String, environmentName: String): String? =
    releaseKeystoreProperties.getProperty(propertyName)
        ?: providers.gradleProperty(propertyName).orNull
        ?: System.getenv(environmentName)

android {
    namespace = "app.ainutrition.companion"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = androidApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = releaseSigningValue(
                "storeFile",
                "AI_NUTRITION_UPLOAD_STORE_FILE",
            )
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
            }
            storePassword = releaseSigningValue(
                "storePassword",
                "AI_NUTRITION_UPLOAD_STORE_PASSWORD",
            )
            keyAlias = releaseSigningValue("keyAlias", "AI_NUTRITION_UPLOAD_KEY_ALIAS")
            keyPassword = releaseSigningValue(
                "keyPassword",
                "AI_NUTRITION_UPLOAD_KEY_PASSWORD",
            )
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
