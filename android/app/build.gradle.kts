import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 正式版(release)的簽署金鑰。key.properties 與金鑰檔都不進 git;建立方式見
// meta repo(mama-fufood)README 上線 SOP 的 Part G。**金鑰一旦用來安裝到手機,之後每一版都要用同一把簽署**,
// 換了金鑰就只能先解除安裝(手機上的資料會不見),所以金鑰檔要備份好。
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = !keyProps.isEmpty

android {
    // 套件名稱,上架後永遠不能改。
    namespace = "tw.com.tutorarthur.mamafufood"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        // DiagnosticsChannel 用 BuildConfig.DEBUG 把除錯工具留在 debug 版。
        buildConfig = true
    }

    defaultConfig {
        applicationId = "tw.com.tutorarthur.mamafufood"
        // 最低支援 Android 11(SPEC 第 13 節):emoji 用 Unicode 13、讀取「上次結束原因」都需要。
        minSdk = 30
        targetSdk = flutter.targetSdkVersion
        // 版本號與版本碼從 pubspec.yaml 帶入(版本碼 = x×1000 + y×10 + z)。
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 沒有 key.properties 時只有在開發者明確允許(環境變數 MFF_ALLOW_DEBUG_SIGNING=1)
            // 才用除錯金鑰簽,避免不小心把除錯金鑰簽的版本裝到家人手機上。
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

// 正式版打包完,另外放一份檔名帶版本號的(例如 mama-fufood-1.1.0.apk),不同版本的安裝檔才分得清楚。
// Flutter 的指令會去找 app-release.apk,所以原檔保留,另外複製一份。
val versionedName = "mama-fufood-${flutter.versionName}"
val versionedCopies = mapOf(
    "assembleRelease" to ("outputs/apk/release/app-release.apk" to "outputs/flutter-apk/$versionedName.apk"),
    "bundleRelease" to ("outputs/bundle/release/app-release.aab" to "outputs/bundle/release/$versionedName.aab"),
)

tasks.configureEach {
    val copy = versionedCopies[name]
    if (copy != null) {
        doLast {
            val dir = layout.buildDirectory.get().asFile
            val target = dir.resolve(copy.second)
            target.parentFile.mkdirs()
            dir.resolve(copy.first).copyTo(target, overwrite = true)
            logger.lifecycle("帶版本號的檔案:$target")
        }
    }
    if (name == "assembleRelease" || name == "bundleRelease") {
        doFirst {
            if (!hasReleaseKey && System.getenv("MFF_ALLOW_DEBUG_SIGNING") != "1") {
                throw GradleException(
                    "缺少 android/key.properties(正式版的簽署金鑰)。請照 meta repo(mama-fufood)README 上線 SOP 的 Part G 建立;" +
                        "只是要在自己的模擬器上試 release 版的話,可以設定環境變數 MFF_ALLOW_DEBUG_SIGNING=1。"
                )
            }
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
