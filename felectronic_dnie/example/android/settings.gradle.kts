pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.12.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.10" apply false
}

include(":app")

// CertificateSigner AAR module for felectronic_certificates_android.
// Resolve relative to this settings file: android/ -> ../../ -> monorepo root
val certSignerDir = file("../../../felectronic_certificates_android/android/certificate-signer")
if (certSignerDir.exists()) {
    include(":certificate-signer")
    project(":certificate-signer").projectDir = certSignerDir
}
