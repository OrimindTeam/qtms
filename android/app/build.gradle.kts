plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "dev.orimind.qtms"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // معرّف التطبيق المعتمد — environments.md §1.1 (RD-002).
        // ⛔ لا يُغيَّر: التطبيق مسجَّل به فعلاً في المشروعين السحابيين.
        applicationId = "dev.orimind.qtms.c001"
        // ★★ أندرويد 7.0 (API 24) حدّاً أدنى — `AM-011` · `CR-010`
        //    (✅ معتمَد بتوقيع المالك 2026-09-02 · `NFR-COMPAT-01`).
        //    ⛔ وليس 26: الأرضيةُ خُفِضت بقرار المالك.
        //
        // ★ وهو الحدُّ الأدنى الافتراضي لـFlutter نفسِه في هذا الإصدار
        //   (`FlutterExtension.minSdkVersion = 24`) — ⛔ ولا يُكتب
        //   `flutter.minSdkVersion` مكانه: القيمةُ قرارُ منتجٍ موثَّق، ★ وربطُها
        //   بالإطار يجعلها تتحرك صامتةً مع أي ترقية SDK.
        //
        // ⛔⛔ ولا تُخفَض دون 24: `url_launcher_android` يُعلن `minSdk = 24`
        //    بالضبط (6.3.30) ⟵ فدونها يفشل دمجُ المانفست.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ★★ نكهتان لبيئتين — `environments.md` §1.1: **الإنتاج `…c001`
    //    والتجريبي `…c001.staging`**. ⚠️ **وكانتا موثَّقتين بلا تنفيذ حتى
    //    2026-08-25** — ⟵ **فكان البناء الوحيد يشير إلى الإنتاج دائماً**،
    //    ★ **وهو ما يخالف «فصل البيئات»** (`environments.md` §2).
    //
    // ⛔★★ **ولكل نكهة ملفُ إعدادها في مجموعة مصادرها** — ⟵ **فلا يُستبدَل
    //    ملفٌ بآخر يدوياً قبل كل بناء**، وهو مسارٌ يُنتج بناءً يشير إلى
    //    البيئة الخطأ **بلا أي علامة ظاهرة**:
    //      android/app/google-services.json              ⟵ الإنتاج
    //      android/app/src/staging/google-services.json  ⟵ التجريبي
    flavorDimensions += "environment"

    productFlavors {
        create("production") {
            dimension = "environment"
            // ⛔ بلا لاحقة — وهو المعرّف المسجَّل في `qtms-orimind-c001`.
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
