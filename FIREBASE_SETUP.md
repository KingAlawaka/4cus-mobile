# 4cus — Firebase Setup Guide

Complete step-by-step to get the 4cus Flutter app talking to Firebase
(Auth, Firestore, Storage). Estimated time: 30–45 minutes.

---

## 1. Create a Firebase project

1. Go to the [Firebase console](https://console.firebase.google.com/).
2. Click **Add project**, name it e.g. `fourcus-app`.
3. Disable Google Analytics (optional) and create the project.

---

## 2. Configure the Flutter app (`flutterfire configure`)

1. Install the FlutterFire CLI (needs the Firebase CLI first):
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   ```
2. Log in: `firebase login`
3. From the repo root, run:
   ```bash
   flutterfire configure
   ```
   Select your Firebase project, then enable **Android**, **iOS** and **Web**
   (in that order; choose the bundle IDs below).
   - Android application ID: `com.fourcus.fourcus`
   - iOS bundle ID: `com.fourcus.fourcus`
4. This overwrites `lib/firebase_options.dart` with real values, replacing
   the `TODO-REPLACE` placeholders.

> Manual alternative: create the apps in the console yourself and paste the
> values into `lib/firebase_options.dart` by hand.

---

## 3. Enable Authentication providers

In the console: **Build → Authentication → Sign-in method**.

1. Enable **Email/Password**.
2. Enable **Google**.
   - For **Android**, Google sign-in needs a SHA-1 certificate fingerprint
     (step 6). The provider can be enabled now; sign-in starts working once
     the fingerprint is added.
   - For **iOS**, download `GoogleService-Info.plist` during app setup
     (step 7).
   - For **Web**, no extra config beyond the authorized domain (step 8).

---

## 4. Create Firestore and deploy the rules

1. In the console: **Build → Firestore Database → Create database**.
2. Choose **production mode** and a region close to your users.
3. Deploy the rules from this repo (from the repo root, with the Firebase
   CLI logged in and the project selected via `firebase use`):
   ```bash
   firebase deploy --only firestore:rules
   ```
   This uploads `firestore.rules`. Key behaviors:
   - `users/{uid}`: readable by any signed-in user, writable by the owner.
   - `goal_posts`: public read for signed-in users; only the owner edits;
     anyone may increment `memberCount` by 1 (join flow).
   - `groups`: single-doc reads allowed for signed-in users (needed for
     invite-code joins); list queries restricted to public groups or groups
     you belong to. Writes enforce the 4-member cap and self-only
     join/leave.
   - `messages` / `checkins` subcollections: group members only.
   - `tasks/{id}` and `usage_days/{uid_date}`: owner only.

---

## 5. Create Storage and deploy the rules

1. In the console: **Build → Storage → Get started** (production mode).
2. Deploy the rules:
   ```bash
   firebase deploy --only storage
   ```
   This uploads `storage.rules`:
   - `profiles/{uid}/**`: signed-in read, owner write.
   - `checkins/{groupId}/**` and `chat/{groupId}/**`: group members only
     (checked via `firestore.get` on the parent group).

---

## 6. Android specifics

1. **SHA-1 for Google sign-in.** Generate your debug keystore fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore \
     -alias androiddebugkey -storepass android -keypass android
   ```
   In the console: **Project settings → Your apps → Android app → Add
   fingerprint**, paste the SHA-1. Repeat for your release keystore.
2. **Usage-stats permission.** Add the snippet from
   `android_snippets/AndroidManifest_snippet.xml` to
   `android/app/src/main/AndroidManifest.xml`. The permission is granted by
   the user in system settings (the app opens that screen for them).
3. **Native usage channel.** Copy
   `android_snippets/MainActivity.kt` into
   `android/app/src/main/kotlin/com/fourcus/fourcus/MainActivity.kt`,
   replacing the default activity (adjust the package if you changed the
   application ID).
4. Ensure `minSdkVersion` is at least 23 in
   `android/app/build.gradle` (UsageStatsManager needs API 22+; 23 is a
   safe floor).

---

## 7. iOS specifics

1. Download `GoogleService-Info.plist` from **Project settings → iOS app**
   and add it to `ios/Runner/` via Xcode (so it lands in the target).
2. Add the **reversed client ID** URL scheme:
   - Open `GoogleService-Info.plist`, copy `REVERSED_CLIENT_ID`.
   - In Xcode: Runner → Info → URL Types → add a scheme with that value.
3. Set the minimum iOS version to 13.0+ in the Podfile if needed.

---

## 8. Web specifics

1. In the console: **Authentication → Settings → Authorized domains** —
   add the domains you will host on (e.g. `localhost`, your hosting
   domain). Firebase Hosting domains are authorized automatically.
2. Phone-usage tracking is Android-only; on web the Focus tab uses manual
   focus sessions (no extra setup).

---

## 9. Data model overview

| Collection | Document ID | Purpose |
|---|---|---|
| `users` | `{uid}` | Profile, onboarding flag, focus target |
| `goal_posts` | auto | Public goals on Discover, links to a group |
| `groups` | auto | max 4 `memberIds`, `inviteCode`, `isPrivate` |
| `groups/{id}/messages` | auto | Chat (text / image) |
| `groups/{id}/checkins` | `{uid}_{yyyy-MM-dd}` | Daily photo + note + `verifiedBy[]` |
| `tasks` | auto | Personal todos with optional `dueAt` |
| `usage_days` | `{uid}_{yyyy-MM-dd}` | Screen minutes / unlocks / focus minutes |

Storage paths: `profiles/{uid}/avatar.jpg`,
`checkins/{groupId}/{uid}_{date}.jpg`, `chat/{groupId}/{uuid}.jpg`.

---

## 10. Testing checklist

- [ ] `flutter pub get` succeeds.
- [ ] `flutterfire configure` generated real `lib/firebase_options.dart`
      (no `TODO-REPLACE` left).
- [ ] App launches past the "Firebase not configured" screen.
- [ ] Email sign-up → user doc appears in `users/`.
- [ ] Google sign-in works on at least one platform.
- [ ] Create public group → post appears on Discover.
- [ ] Join via invite code on a second account → member count 2/4.
- [ ] 5th join attempt is rejected ("group is full").
- [ ] Chat text + image send and appear in realtime.
- [ ] Daily check-in photo posts; peer can Verify; self-verify blocked.
- [ ] Tasks: add with deadline, check off, delete.
- [ ] Android: grant usage access → Focus shows today's screen time.
- [ ] iOS/web: focus session timer runs and saves minutes.
- [ ] Private group is invisible in list queries to non-members.
- [ ] Sign out → back to auth screen.
