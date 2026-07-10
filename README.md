# EventFlow 🎉

An event planning and management Flutter application with Firebase backend.

## ⚠️ Firebase Setup (Required)

This project uses Firebase. The credential files are **not included** in the repository for security reasons. You must configure them before running the app.

### Step 1: Clone the repository

```bash
git clone https://github.com/MalaikaAltaf/eventflow.git
cd eventflow
```

### Step 2: Configure Firebase credentials

**`lib/firebase_options.dart`**
```bash
# Copy the example template
cp lib/firebase_options.dart.example lib/firebase_options.dart
```
Then fill in your actual Firebase credentials from the [Firebase Console](https://console.firebase.google.com).  
_(Or run `flutterfire configure` to auto-generate it.)_

**`android/app/google-services.json`**  
Download your `google-services.json` from Firebase Console → Project Settings → Android app, and place it at `android/app/google-services.json`.

### Step 3: Install dependencies

```bash
flutter pub get
```

### Step 4: Run the app

```bash
flutter run
```

---

## Tech Stack

- **Flutter** — Cross-platform UI framework
- **Firebase Auth** — Authentication
- **Cloud Firestore** — Database
- **Firebase Core** — Firebase initialization
- **Riverpod** — State management
- **Go Router** — Navigation
- **Google Fonts** — Typography
- **FL Chart** — Charts & analytics

## Features

- Event planning and management
- Vendor discovery and booking
- Real-time chat / negotiation
- Multi-language support (easy_localization)
- Calendar integration

---

> **Security Note:** Never commit `firebase_options.dart`, `google-services.json`, or `GoogleService-Info.plist` to version control. These files are listed in `.gitignore`.
