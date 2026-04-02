# Play Store Submission Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the PlantDoctor Android app for Play Store submission by changing the app ID, setting up release signing, creating a privacy policy page, and building a signed AAB.

**Architecture:** Four sequential tasks: (1) app ID change across Android config + Kotlin source, (2) release signing config wired into Gradle, (3) privacy policy HTML page in `docs/`, (4) signed AAB build. Tasks 1–3 are code-only and commit independently. Task 4 requires user manual steps (keystore generation + Firebase update) before the build runs.

**Tech Stack:** Flutter, Android Gradle (Kotlin DSL), Firebase, GitHub Pages (static HTML).

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `android/app/build.gradle.kts` | App ID (Task 1) + signing config (Task 2) |
| Modify | `android/app/src/main/AndroidManifest.xml` | App display name |
| Create | `android/app/src/main/kotlin/com/plantdoctor/app/MainActivity.kt` | New package location |
| Delete | `android/app/src/main/kotlin/com/example/` | Old package directory |
| Modify | `.gitignore` | Exclude keystore files |
| Create | `android/key.properties` | Signing credentials (gitignored, not committed) |
| Create | `docs/privacy-policy.html` | Hosted privacy policy |

---

## Task 1: Change app ID + update gitignore + fix app label

**Files:**
- Modify: `.gitignore`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/kotlin/com/plantdoctor/app/MainActivity.kt`
- Delete: `android/app/src/main/kotlin/com/example/` (entire directory)

No unit tests apply to build config. Verification is `flutter analyze` + `flutter build apk --debug`.

- [ ] **Step 1: Add keystore exclusions to `.gitignore`**

Open `.gitignore` and add these lines in the "Project-specific exclusions" section (after the `android/local.properties` entry):

```
# Android release signing — never commit keystore or credentials
android/key.properties
*.jks
*.keystore
```

- [ ] **Step 2: Update `android/app/build.gradle.kts` — change namespace and applicationId**

Replace only these two lines (leave everything else unchanged):

Find:
```kotlin
    namespace = "com.example.plant_doctor"
```
Replace with:
```kotlin
    namespace = "com.plantdoctor.app"
```

Find:
```kotlin
        applicationId = "com.example.plant_doctor"
```
Replace with:
```kotlin
        applicationId = "com.plantdoctor.app"
```

- [ ] **Step 3: Update app display name in `android/app/src/main/AndroidManifest.xml`**

Find:
```xml
        android:label="plant_doctor"
```
Replace with:
```xml
        android:label="PlantDoctor"
```

- [ ] **Step 4: Create new `MainActivity.kt` at the correct package path**

Create file `android/app/src/main/kotlin/com/plantdoctor/app/MainActivity.kt`:

```kotlin
package com.plantdoctor.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

- [ ] **Step 5: Delete the old package directory**

```bash
cd D:/Documents/ext/plant/pd
rm -rf android/app/src/main/kotlin/com/example
```

- [ ] **Step 6: Verify with flutter analyze**

```bash
cd D:/Documents/ext/plant/pd
flutter analyze
```

Expected: no errors. Warnings about unused imports or info-level hints are acceptable.

- [ ] **Step 7: Verify with a debug build**

```bash
cd D:/Documents/ext/plant/pd
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 8: Commit**

```bash
cd D:/Documents/ext/plant/pd
git add .gitignore android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml
git add -A android/app/src/main/kotlin/
git commit -m "feat: change app ID to com.plantdoctor.app, update display name"
```

Note: `git add -A android/app/src/main/kotlin/` stages both the new `com/plantdoctor/app/MainActivity.kt` and the deletion of the old `com/example/plant_doctor/MainActivity.kt`.

---

## Task 2: Add release signing configuration

**Files:**
- Create: `android/key.properties` (gitignored — will NOT be committed)
- Modify: `android/app/build.gradle.kts`

- [ ] **Step 1: Create `android/key.properties` with placeholder values**

Create `android/key.properties` (this file is gitignored — the user will fill in real values before building):

```
storePassword=FILL_IN_YOUR_KEYSTORE_PASSWORD
keyPassword=FILL_IN_YOUR_KEY_PASSWORD
keyAlias=plantdoctor
storeFile=C:/Users/youss/keys/plantdoctor.jks
```

- [ ] **Step 2: Replace `android/app/build.gradle.kts` with the full signing-enabled version**

```kotlin
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.plantdoctor.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.plantdoctor.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

- [ ] **Step 3: Verify the Gradle file is valid**

```bash
cd D:/Documents/ext/plant/pd
flutter analyze
```

Expected: no errors.

- [ ] **Step 4: Verify debug build still works (signing config is conditional on key.properties existing)**

```bash
cd D:/Documents/ext/plant/pd
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 5: Commit (key.properties is gitignored and will not be included)**

```bash
cd D:/Documents/ext/plant/pd
git add android/app/build.gradle.kts
git commit -m "feat: add release signing config to build.gradle.kts"
```

---

## Task 3: Create privacy policy page

**Files:**
- Create: `docs/privacy-policy.html`

- [ ] **Step 1: Create `docs/privacy-policy.html`**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PlantDoctor — Privacy Policy</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      max-width: 800px;
      margin: 40px auto;
      padding: 0 24px;
      color: #222;
      line-height: 1.7;
      font-size: 16px;
    }
    h1 { color: #1b4332; border-bottom: 2px solid #40916c; padding-bottom: 12px; }
    h2 { color: #2d6a4f; margin-top: 2em; }
    a { color: #2d6a4f; }
    ul { padding-left: 1.4em; }
    li { margin-bottom: 6px; }
    .updated { color: #666; font-size: 14px; }
  </style>
</head>
<body>

  <h1>PlantDoctor &mdash; Privacy Policy</h1>
  <p class="updated"><strong>Last updated:</strong> April 2, 2026</p>

  <p>PlantDoctor (&ldquo;we&rdquo;, &ldquo;our&rdquo;, or &ldquo;us&rdquo;) is committed to protecting your privacy.
  This policy explains what data we collect, how we use it, and your rights as a user.</p>

  <h2>1. Data We Collect</h2>

  <p><strong>Photos.</strong> When you scan a plant, your photo is uploaded to Firebase Storage
  and sent to our plant identification and diagnosis services for processing. Photos are stored
  under your account and deleted when you delete your account.</p>

  <p><strong>Location.</strong> If you grant location permission, your approximate GPS coordinates
  are used solely to fetch local weather data for personalised care advice. Coordinates are not
  stored on our servers &mdash; they are used only at the moment of the request.</p>

  <p><strong>Account data.</strong> You may use the app as a guest (no sign-in required) or sign
  in with Google or email. Guest sessions are identified by an anonymous ID only. If you sign in,
  we store your email address and display name via Firebase Authentication.</p>

  <p><strong>Scan history.</strong> Your plant scan results &mdash; species name, health diagnosis,
  and care advice &mdash; are stored in your account in Firebase Firestore so you can access them
  across sessions and devices.</p>

  <p><strong>Usage data.</strong> We use Firebase Analytics to collect anonymised usage statistics
  (screens viewed, features used). No personally identifiable information is included in
  analytics events.</p>

  <h2>2. Third-Party Services</h2>

  <p>PlantDoctor uses the following third-party services to deliver its features:</p>
  <ul>
    <li><strong>Firebase (Google)</strong> &mdash; authentication, database, file storage, and
    analytics.
    <a href="https://firebase.google.com/support/privacy" target="_blank">Privacy policy</a></li>

    <li><strong>Pl@ntNet API</strong> &mdash; plant species identification. Your photo is sent
    to Pl@ntNet for processing.
    <a href="https://plantnet.org/en/privacy-policy/" target="_blank">Privacy policy</a></li>

    <li><strong>OpenWeatherMap</strong> &mdash; local weather data. Only your approximate
    coordinates are sent; no account data is shared.
    <a href="https://openweather.co.uk/privacy-policy" target="_blank">Privacy policy</a></li>

    <li><strong>Anthropic Claude</strong> &mdash; AI-powered plant health diagnosis. Your photo
    and identified species name are sent to Anthropic for analysis.
    <a href="https://www.anthropic.com/privacy" target="_blank">Privacy policy</a></li>
  </ul>

  <h2>3. How We Use Your Data</h2>
  <ul>
    <li>To identify plant species and diagnose health issues</li>
    <li>To personalise care advice using local weather conditions</li>
    <li>To store and display your scan history across devices</li>
    <li>To send watering reminders and care alerts (only if you enable notifications)</li>
    <li>To improve the app through anonymised usage analytics</li>
  </ul>
  <p>We do not sell your personal data to third parties.</p>

  <h2>4. Data Retention &amp; Deletion</h2>

  <p>Your scan history and account data are retained until you request deletion.
  To request deletion of all your data, contact us at
  <a href="mailto:squid55644@gmail.com">squid55644@gmail.com</a> with the subject line
  &ldquo;Delete my data&rdquo;. We will permanently remove all your data within 30 days.</p>

  <h2>5. Children&rsquo;s Privacy</h2>

  <p>PlantDoctor is not directed at children under the age of 13. We do not knowingly collect
  personal information from children under 13. If you believe a child has provided us with
  personal information, please contact us so we can delete it.</p>

  <h2>6. Changes to This Policy</h2>

  <p>We may update this policy from time to time. The &ldquo;Last updated&rdquo; date at the top
  reflects when changes were last made. Continued use of the app after changes constitutes
  acceptance of the updated policy.</p>

  <h2>7. Contact</h2>

  <p>Questions about this privacy policy or your data?
  Email us at <a href="mailto:squid55644@gmail.com">squid55644@gmail.com</a>.</p>

</body>
</html>
```

- [ ] **Step 2: Commit**

```bash
cd D:/Documents/ext/plant/pd
git add docs/privacy-policy.html
git commit -m "feat: add privacy policy page for Play Store submission"
```

---

## Task 4: Build signed AAB

**⚠️ MANUAL PREREQUISITES — complete these before running any commands in this task:**

**A) Generate keystore** (run once in a terminal, outside the project):
```bash
mkdir -p C:/Users/youss/keys
keytool -genkey -v -keystore C:/Users/youss/keys/plantdoctor.jks -keyalg RSA -keysize 2048 -validity 10000 -alias plantdoctor
```
You will be prompted for a keystore password, key password, and your name/organisation details. Remember both passwords — you need them in the next step.

**B) Fill in `android/key.properties`** — replace the placeholders with your real values:
```
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=plantdoctor
storeFile=C:/Users/youss/keys/plantdoctor.jks
```

**C) Add `com.plantdoctor.app` to Firebase Console:**
1. Go to console.firebase.google.com → your project → Project Settings
2. Under "Your apps" → Android app → Add fingerprint or add package
3. Add package name: `com.plantdoctor.app`
4. Download the new `google-services.json`
5. Place it at `android/app/google-services.json` (replaces the existing file)

---

- [ ] **Step 1: Verify key.properties is filled in**

```bash
cd D:/Documents/ext/plant/pd
cat android/key.properties
```

Expected: file shows real passwords (not `FILL_IN_*` placeholders) and the storeFile path exists.

- [ ] **Step 2: Verify google-services.json contains the new package name**

```bash
grep "com.plantdoctor.app" android/app/google-services.json
```

Expected: at least one match (the `package_name` field).

- [ ] **Step 3: Build the release AAB**

```bash
cd D:/Documents/ext/plant/pd
flutter build appbundle --release
```

Expected output ends with:
```
Built build/app/outputs/bundle/release/app-release.aab (XX.X MB).
```

- [ ] **Step 4: Verify the AAB exists**

```bash
ls -lh D:/Documents/ext/plant/pd/build/app/outputs/bundle/release/app-release.aab
```

Expected: file exists, size > 20 MB.

- [ ] **Step 5: Done — upload to Play Console**

The file at `build/app/outputs/bundle/release/app-release.aab` is ready to upload at
https://play.google.com/console → your app → Production (or Internal testing) → Create new release → Upload.

Use this store listing text in Play Console:

**App name:** PlantDoctor

**Short description (80 chars max):**
```
Identify any plant & diagnose diseases. Point, shoot, know.
```

**Full description:**
```
PlantDoctor turns your camera into an expert plant advisor. Point it at any plant and get instant species identification, health diagnosis, and personalised care advice — all in seconds.

What PlantDoctor does:
• Species identification with confidence rating
• Health diagnosis — detects diseases, pests, and deficiencies
• Weather-smart care advice based on your real local conditions
• Frost alerts and rain-skip watering reminders
• Watering reminders timed to your plant's actual needs
• Health timeline — track how your plant improves over time
• Works offline — results cached locally

How it works:
Take a photo or pick one from your gallery. PlantDoctor identifies the species, checks for signs of disease, and gives you a step-by-step treatment plan — factoring in your local weather so advice is always relevant.

No plant expertise required. No subscriptions needed to get started.
```

**Privacy policy URL:**
```
https://yzerr0.github.io/plant-doctor/privacy-policy
```
(Enable GitHub Pages first: repo Settings → Pages → branch master, folder /docs)

**Category:** Tools
**Content rating:** Everyone
