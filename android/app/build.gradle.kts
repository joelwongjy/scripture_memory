import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.play.publisher)
}

val release = Properties().apply { rootDir.resolve("../VERSION").inputStream().use(::load) }
val releaseVersion: String = release.getProperty("version")
val releaseBuild = release.getProperty("build").toInt()
val versionParts = releaseVersion.split(".").map(String::toInt)

val configDir = File(
    System.getenv("SCRIPTURE_MEMORY_CONFIG") ?: "${System.getProperty("user.home")}/.config/scripture-memory",
)
val signing = configDir.resolve("android-signing.properties").takeIf(File::exists)?.let { file ->
    Properties().apply { file.inputStream().use(::load) }
}

android {
    namespace = "joel.scripturememory"
    compileSdk = 37

    defaultConfig {
        applicationId = "joel.scripturememory"
        minSdk = 26
        targetSdk = 36
        versionCode = versionParts[0] * 1_000_000 + versionParts[1] * 10_000 + versionParts[2] * 100 + releaseBuild
        versionName = releaseVersion
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    sourceSets {
        getByName("main") {
            assets.srcDir("../../scripture memory/Resources")
        }
    }

    signingConfigs {
        if (signing != null) {
            create("upload") {
                storeFile = configDir.resolve(signing.getProperty("storeFile"))
                storePassword = signing.getProperty("storePassword")
                keyAlias = signing.getProperty("keyAlias")
                keyPassword = signing.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isIncludeAndroidResources = true
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.process)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.foundation)
    implementation(libs.compose.ui)
    implementation(libs.compose.animation)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.glance.appwidget)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    debugImplementation(libs.compose.ui.tooling)
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
}

play {
    serviceAccountCredentials.set(configDir.resolve("play-service-account.json"))
    track.set("internal")
    defaultToAppBundles.set(true)
}
