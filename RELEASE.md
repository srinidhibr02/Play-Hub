# Releasing Play Hub

## One-time setup

1. Copy `android/key.properties.example` to `android/key.properties` and fill
   in your keystore path, passwords and alias. The file is git-ignored.
   Without it, release builds fall back to the debug key (fine for testing,
   not accepted by Google Play).
2. Make sure `android/app/src/prod/google-services.json` is the Firebase
   config for the `prod` app (`app.zerolpa.playhub`).
3. Deploy Firestore rules (see the warning in `firestore.rules`) and enable
   Email/Password and Google sign-in in the Firebase console.
4. Google sign-in on Android needs the SHA-1 and SHA-256 of both the debug and
   release keys registered in the Firebase console, then re-download
   `google-services.json`.

## Each release

1. Bump `version:` in `pubspec.yaml`. The number after `+` is the Android
   `versionCode` and must go up every upload (the last one before this rewrite
   was 12, so this version starts at 13).
2. `flutter test`
3. `flutter build appbundle --flavor prod --dart-define=FLAVOR=prod`
4. Upload `build/app/outputs/bundle/prodRelease/app-prod-release.aab` to the
   Play Console.

## Things to know

- The `dev` flavor uses `com.example.play_hub`, the `prod` flavor uses
  `app.zerolpa.playhub`. Changing either needs a matching Firebase app and
  `google-services.json`.
- An older version of `android/app/build.gradle.kts` had the release keystore
  password written in it. That value is still in git history. If this
  repository is or becomes public, change the keystore password (or create a
  new upload key via Play App Signing) rather than relying on it staying
  private.
