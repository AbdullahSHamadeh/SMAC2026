import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Keep the checked-in demo build independent from Firebase. A configured
// build applies Google Services as soon as its gitignored native file exists.
val hasGoogleServicesConfig =
    file("google-services.json").isFile ||
        file("src").walkTopDown().any { it.isFile && it.name == "google-services.json" }
if (hasGoogleServicesConfig) {
    apply(plugin = "com.google.gms.google-services")
}

val releaseSigningProperties = Properties()
val releaseSigningFile = rootProject.file("key.properties")
if (releaseSigningFile.isFile) {
    FileInputStream(releaseSigningFile).use(releaseSigningProperties::load)
}

fun Properties.nonBlankProperty(name: String): String? =
    getProperty(name)?.trim()?.takeIf(String::isNotEmpty)

fun firstEnvironmentValue(vararg names: String): String? {
    for (name in names) {
        val value = System.getenv(name)
        if (!value.isNullOrEmpty()) {
            return value
        }
    }
    return null
}

fun environmentSecret(propertyName: String, vararg defaultNames: String): String? {
    val configuredName = releaseSigningProperties.nonBlankProperty(propertyName)
    if (configuredName != null) {
        val configuredValue = System.getenv(configuredName)
        if (!configuredValue.isNullOrEmpty()) {
            return configuredValue
        }
    }
    return firstEnvironmentValue(*defaultNames)
}

fun keychainSecret(serviceProperty: String, accountProperty: String): String? {
    val service = releaseSigningProperties.nonBlankProperty(serviceProperty) ?: return null
    val isMacOs = System.getProperty("os.name").lowercase().contains("mac")
    if (!isMacOs) {
        return null
    }

    val command = mutableListOf("security", "find-generic-password", "-w", "-s", service)
    releaseSigningProperties.nonBlankProperty(accountProperty)?.let { account ->
        command.addAll(listOf("-a", account))
    }

    return try {
        val process = ProcessBuilder(command).start()
        val output = process.inputStream.bufferedReader().use { it.readText() }
        process.errorStream.bufferedReader().use { it.readText() }
        if (process.waitFor() == 0) {
            output.trimEnd('\r', '\n').takeIf(String::isNotEmpty)
        } else {
            null
        }
    } catch (_: Exception) {
        null
    }
}

val releaseStoreFilePath =
    firstEnvironmentValue(
        "FAMILY_COMPASS_ANDROID_KEYSTORE_PATH",
        "ANDROID_KEYSTORE_PATH",
    ) ?: releaseSigningProperties.nonBlankProperty("storeFile")
val releaseKeyAlias =
    firstEnvironmentValue(
        "FAMILY_COMPASS_ANDROID_KEY_ALIAS",
        "ANDROID_KEY_ALIAS",
    ) ?: releaseSigningProperties.nonBlankProperty("keyAlias")
val releaseStorePassword =
    environmentSecret(
        "storePasswordEnv",
        "FAMILY_COMPASS_ANDROID_STORE_PASSWORD",
        "ANDROID_KEYSTORE_PASSWORD",
    ) ?: keychainSecret("storePasswordKeychainService", "storePasswordKeychainAccount")
        ?: releaseSigningProperties.getProperty("storePassword")?.takeIf(String::isNotEmpty)
val releaseKeyPassword =
    environmentSecret(
        "keyPasswordEnv",
        "FAMILY_COMPASS_ANDROID_KEY_PASSWORD",
        "ANDROID_KEY_PASSWORD",
    ) ?: keychainSecret("keyPasswordKeychainService", "keyPasswordKeychainAccount")
        ?: releaseSigningProperties.getProperty("keyPassword")?.takeIf(String::isNotEmpty)

val releaseSigningEnvironmentNames =
    listOf(
        "FAMILY_COMPASS_ANDROID_KEYSTORE_PATH",
        "FAMILY_COMPASS_ANDROID_KEY_ALIAS",
        "FAMILY_COMPASS_ANDROID_STORE_PASSWORD",
        "FAMILY_COMPASS_ANDROID_KEY_PASSWORD",
        "ANDROID_KEYSTORE_PATH",
        "ANDROID_KEY_ALIAS",
        "ANDROID_KEYSTORE_PASSWORD",
        "ANDROID_KEY_PASSWORD",
    )
val hasReleaseSigningConfiguration =
    releaseSigningFile.isFile ||
        releaseSigningEnvironmentNames.any { !System.getenv(it).isNullOrEmpty() }

android {
    namespace = "com.smac.familycompass"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.smac.familycompass"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningConfiguration) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = releaseStoreFilePath?.let(::file)
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        getByName("profile") {
            // A distributable profile build must use the protected upload key,
            // never Flutter's local debug identity.
            signingConfig = if (hasReleaseSigningConfiguration) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
        release {
            // Never fall back to the debug identity. CI or the release owner
            // supplies a protected upload key and its secret references.
            if (hasReleaseSigningConfiguration) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

val validateReleaseSigning by tasks.registering {
    group = "verification"
    description = "Validates Android upload-key signing without printing secrets."

    doLast {
        val problems = mutableListOf<String>()
        if (releaseStoreFilePath == null) {
            problems.add("upload keystore path is missing")
        } else if (!file(releaseStoreFilePath).isFile) {
            problems.add("upload keystore file does not exist")
        }
        if (releaseKeyAlias == null) {
            problems.add("upload key alias is missing")
        }
        if (releaseStorePassword == null) {
            problems.add("keystore password could not be resolved")
        }
        if (releaseKeyPassword == null) {
            problems.add("key password could not be resolved")
        }

        if (problems.isNotEmpty()) {
            throw GradleException(
                "Android release signing is incomplete: ${problems.joinToString()}. " +
                    "Use key.properties with macOS Keychain service references, " +
                    "CI environment variables, or the legacy plaintext properties.",
            )
        }
        logger.lifecycle("Android release signing configuration is complete.")
    }
}

tasks.matching { it.name == "preProfileBuild" || it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseSigning)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
