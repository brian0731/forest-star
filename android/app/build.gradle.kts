import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Never silently submit a release signed with the Android debug certificate.
val uploadPropertiesFile = rootProject.file("key.properties")
val uploadProperties = Properties()
if (uploadPropertiesFile.exists()) {
    FileInputStream(uploadPropertiesFile).use { uploadProperties.load(it) }
}
val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (releaseRequested && !uploadPropertiesFile.exists()) {
    throw GradleException("Release signing is missing. Configure android/key.properties using the existing upload key, or run tool/setup_upload_key.ps1 for a new Play app.")
}

// One Flutter build configuration supplies both native and Dart advertising IDs.
val adDefines = (project.findProperty("dart-defines") as? String).orEmpty()
    .split(",").filter { it.isNotEmpty() }.associate {
        val pair = String(Base64.getDecoder().decode(it), Charsets.UTF_8).split("=", limit = 2)
        pair[0] to pair.getOrElse(1) { "" }
    }
val adProduction = adDefines["ADMOB_PRODUCTION"] == "true"
val adAppId = if (adProduction) adDefines["ADMOB_APP_ID"].orEmpty() else "ca-app-pub-3940256099942544~3347511713"
if (adProduction && (
    !Regex("ca-app-pub-[0-9]{16}~[0-9]{10}").matches(adAppId) ||
    !Regex("ca-app-pub-[0-9]{16}/[0-9]{10}").matches(adDefines["ADMOB_REWARDED_ID"].orEmpty()) ||
    adAppId.contains("3940256099942544") ||
    adDefines["ADMOB_REWARDED_ID"].orEmpty().contains("3940256099942544") ||
    adDefines["ADMOB_AUDIENCE"] !in listOf("children", "general")
)) throw GradleException("Production ads require your real ADMOB_APP_ID, ADMOB_REWARDED_ID and a confirmed ADMOB_AUDIENCE (children/general).")
if (releaseRequested && !adProduction && adDefines["ADMOB_ALLOW_TEST_RELEASE"] != "true") {
    throw GradleException("This is a test-ad build. Supply real AdMob configuration for Play, or explicitly set ADMOB_ALLOW_TEST_RELEASE=true for a local QA build.")
}

android {
    namespace = "com.foreststar.forest_star"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.foreststar.forest_star"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = adAppId
    }

    signingConfigs {
        create("upload") {
            if (uploadPropertiesFile.exists()) {
                storeFile = file(uploadProperties.getProperty("storeFile"))
                storePassword = uploadProperties.getProperty("storePassword")
                keyAlias = uploadProperties.getProperty("keyAlias")
                keyPassword = uploadProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("upload")
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
