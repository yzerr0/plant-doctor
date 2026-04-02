# PlantDoctor — Play Store Submission Prep Design

**Date:** 2026-04-02
**Version target:** v1.0
**Status:** Approved, ready for implementation

---

## Goal

Prepare the PlantDoctor Android app for submission to Google Play Store: change the app ID from the placeholder `com.example.plant_doctor` to `com.plantdoctor.app`, set up release signing, create a hosted privacy policy, and produce a signed AAB ready to upload.

---

## What I Implement (Code Changes)

| Action | File |
|--------|------|
| Modify | `android/app/build.gradle.kts` — update `applicationId`, `namespace`, add signing config |
| Rename dir + modify | `android/app/src/main/kotlin/com/example/plant_doctor/` → `com/plantdoctor/app/` + update `MainActivity.kt` package declaration |
| Modify | `android/app/src/main/AndroidManifest.xml` — verify no hardcoded package refs |
| Modify | `.gitignore` — add `android/key.properties` and `*.jks` |
| Create | `android/key.properties` — template with placeholders for keystore path + passwords |
| Create | `docs/privacy-policy.html` — full privacy policy for PlantDoctor |
| Build | `flutter build appbundle --release` — produces signed AAB |

---

## What You Do Manually (External Steps)

In order:

1. **Generate keystore** — run this command once, store the `.jks` file outside the project:
   ```
   keytool -genkey -v -keystore C:/Users/youss/keys/plantdoctor.jks -keyalg RSA -keysize 2048 -validity 10000 -alias plantdoctor
   ```
   **Back it up. If lost, you can never update the app on Play Store.**

2. **Fill in `android/key.properties`** — replace placeholders with your keystore path and passwords after I create the template.

3. **Firebase Console** — go to Project Settings → Android app → Add fingerprint / package name → add `com.plantdoctor.app` → download new `google-services.json` → place at `android/app/google-services.json`.

4. **GitHub Pages** — repo Settings → Pages → Deploy from branch `master`, folder `/docs` → Save. Privacy policy will be at `https://yzerr0.github.io/plant-doctor/privacy-policy`.

5. **Play Console** — upload `build/app/outputs/bundle/release/app-release.aab`, fill store listing, submit for review.

---

## App ID Change

| Field | Before | After |
|-------|--------|-------|
| `applicationId` | `com.example.plant_doctor` | `com.plantdoctor.app` |
| `namespace` | `com.example.plant_doctor` | `com.plantdoctor.app` |
| Kotlin package dir | `com/example/plant_doctor/` | `com/plantdoctor/app/` |
| `MainActivity.kt` package | `com.example.plant_doctor` | `com.plantdoctor.app` |

No `AndroidManifest.xml` changes needed — it uses `${applicationId}` placeholder already.

---

## Signing Configuration

`android/key.properties` (gitignored, you fill in values):
```
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=plantdoctor
storeFile=C:/Users/youss/keys/plantdoctor.jks
```

`build.gradle.kts` changes:
- Read `key.properties` file at build time
- Add `signingConfigs { release { ... } }` block using the properties
- Set `buildTypes { release { signingConfig = signingConfigs.getByName("release") } }`

---

## Privacy Policy

File: `docs/privacy-policy.html`
URL (after GitHub Pages enabled): `https://yzerr0.github.io/plant-doctor/privacy-policy`
Contact email: `squid55644@gmail.com`

Covers:
- Data collected: photos (processed, not stored by us), location (weather only), Firebase Analytics usage data, Firebase Auth (anonymous or signed-in)
- Third-party services: Firebase (Google), PlantNet API, OpenWeatherMap, Anthropic Claude API
- Data retention and deletion (delete account removes all data)
- User rights
- Contact information

---

## Store Listing Text (for Play Console)

**App name:** PlantDoctor

**Short description (80 chars):**
> Identify any plant & diagnose diseases. Point, shoot, know.

**Full description:**
> PlantDoctor turns your camera into an expert plant advisor. Point it at any plant and get instant species identification, health diagnosis, and personalised care advice — all in seconds.
>
> **What PlantDoctor does:**
> • Species identification with confidence rating
> • Health diagnosis — detects diseases, pests, and deficiencies
> • Weather-smart care advice based on your real local conditions
> • Frost alerts and rain-skip watering reminders
> • Watering reminders timed to your plant's actual needs
> • Health timeline — track how your plant improves over time
> • Works offline — results cached locally
>
> **How it works:**
> Take a photo or pick one from your gallery. PlantDoctor identifies the species, checks for signs of disease, and gives you a step-by-step treatment plan — factoring in your local weather so advice is always relevant.
>
> No plant expertise required. No subscriptions needed to get started.

**Category:** Tools

**Content rating:** Everyone

---

## Out of Scope

- iOS submission (deferred — no iOS-specific work in this task)
- App icon redesign (current icon used as-is)
- In-app purchases / RevenueCat (v0.6, deferred post-launch)
- Play Store screenshots (taken manually by user after AAB upload)
