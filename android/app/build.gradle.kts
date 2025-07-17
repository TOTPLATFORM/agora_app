plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("org.jetbrains.kotlin.android")
}

configurations.all {
    resolutionStrategy {
        force("io.agora.rtm:rtm-sdk:2.2.4")
    }
}
android {
    namespace = "com.example.agora_test_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"
    
  packagingOptions {
        pickFirsts.addAll(
            listOf(
                "lib/**/libc++_shared.so",
                "lib/**/libagora-rtc-sdk-jni.so",
                "lib/**/libagora-rtm-sdk-jni.so"
            )
        )
    }

      packagingOptions {
        pickFirst("lib/arm64-v8a/libaosl.so")
        pickFirst("lib/armeabi-v7a/libaosl.so")
        pickFirst("lib/x86/libaosl.so")
        pickFirst("lib/x86_64/libaosl.so")
    }


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.agora_test_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
         ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    packagingOptions {
        pickFirst("lib/**/libc++_shared.so")
        pickFirst("lib/**/libagora-*.so")
        exclude("lib/**/libaosl.so")
        exclude("lib/arm64-v8a/libaosl.so")
        pickFirst("lib/**/libc++_shared.so")
        pickFirst("lib/**/libagora-rtc-sdk.so")
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("io.agora.rtc:full-sdk:4.2.6") {
    }
}