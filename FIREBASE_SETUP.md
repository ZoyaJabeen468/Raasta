# Firebase setup (Sign up / Sign in / Social / Forgot password)

Email + Google + Facebook need a free Firebase project.

## 1. Create project

1. Open [Firebase Console](https://console.firebase.google.com/)
2. **Add project** → name it `raasta` (or any name)
3. Disable Google Analytics if you want (optional)

## 2. Enable Email/Password auth

1. **Build → Authentication → Get started**
2. **Sign-in method → Email/Password → Enable → Save**

## 3. Enable Google Sign-In

1. **Authentication → Sign-in method → Google → Enable → Save**
2. Register an **Android** app with package `com.raasta.raasta`
3. Add your **SHA-1** debug fingerprint:
   ```powershell
   cd android
   .\gradlew signingReport
   ```
   Copy SHA-1 from `Variant: debug` into Firebase Android app settings.
4. Download `google-services.json` into `android/app/`
5. In Google Cloud Console (linked to the Firebase project) copy the
   **OAuth 2.0 Web client** ID (`….apps.googleusercontent.com`)
6. Paste it into `lib/firebase_options.dart`:
   ```dart
   static const String googleWebClientId = 'YOUR_ID.apps.googleusercontent.com';
   ```
7. Run `flutterfire configure` (or keep existing keys) and **full restart** the app

## 4. Enable Facebook Sign-In

1. Create an app at [Facebook Developers](https://developers.facebook.com/)
2. Add **Facebook Login** product → get **App ID** + **Client Token**
3. In Firebase: **Authentication → Sign-in method → Facebook → Enable**
   (paste App ID + App Secret)
4. In `android/app/src/main/res/values/strings.xml` replace:
   ```xml
   <string name="facebook_app_id">1234567890</string>
   <string name="facebook_client_token">abcdef...</string>
   <string name="fb_login_protocol_scheme">fb1234567890</string>
   ```
5. Add your Android package + key hash in the Facebook app settings
6. Full restart the app

## 5. Register apps / FlutterFire

Add at least:

- **Web** (Chrome testing)
- **Android** package: `com.raasta.raasta`

```powershell
cd E:\Android\projects\raasta_app
dart pub global activate flutterfire_cli
flutterfire configure
```

## 6. Restart

```powershell
flutter pub get
flutter run
```

## Password rules (email sign-up)

App requires:

- At least **8** characters  
- One **uppercase** letter  
- One **lowercase** letter  
- One **number**  
- One **special** character  

## Notes

- Check spam for reset emails.
- Google/Facebook buttons show a clear error if the provider is not enabled yet.
- For demos, email/password always works once Firebase Email auth is on.
