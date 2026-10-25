# Exerlio 3.0 — Setup

Two parts. Backend first, then the app.

| Folder | What it is |
|---|---|
| `backend/exerlio/` | Django app. Replaces your v2 `exerlio/` folder. |
| `flutter/` | Flutter app. Replaces `lib/`, `pubspec.yaml`, `assets/`, platform files. |
| `Exerlio_App_Flow.pdf` | App flow + store-release checklist. |

---

## Part 1 — Backend (Django)

### 1. Replace the app folder

```
your_project/
├── manage.py
├── your_project/settings.py
├── exerlio/          ← delete the old one, copy the new one here
```

### 2. settings.py

`INSTALLED_APPS` already has `"rest_framework"` and `"exerlio"` from v2. Add these:

```python
# Photos, reels, stories, avatars
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

# "Forgot password" sends a 6-digit code by email
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = "smtp.gmail.com"          # or your mail provider
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = "no-reply@yourdomain.com"
EMAIL_HOST_PASSWORD = "app-password-here"
DEFAULT_FROM_EMAIL = "Exerlio <no-reply@yourdomain.com>"
```

Gemini key: no change. Any of these names works: `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `GEMINI_KEY`, `GEMINI_API`, `GOOGLE_GEMINI_API_KEY`. The key stays on the server. The app never sees it.

### 3. Serve uploaded files

Add to `/etc/nginx/sites-available/<your site>` inside the `server { }` block:

```nginx
client_max_body_size 100M;          # reels up to 80 MB

location /media/ {
    alias /path/to/your_project/media/;
}
```

Then: `sudo nginx -t && sudo systemctl reload nginx`

### 4. Migrate and load the demo data

```bash
python manage.py migrate exerlio
python manage.py seed_exerlio --reset
```

| Migration | What it does |
|---|---|
| `0002_clear_v2_demo` | Deletes the old v2 demo rows (the v2 data shape does not fit v3) |
| `0003_v3` | New tables and columns |

You should see:

```
Exerlio seed loaded. Log in with akif@exerlio.in (or 9876543210) / Exerlio@123  (targets: 2850 kcal, 133 g protein)
```

> Warning: `--reset` wipes every `exerlio_*` row. Run it only before go-live, never on real users.

### 5. Test

```bash
curl -X POST https://api.chandus7.in/api/exerlio/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"identifier":"akif@exerlio.in","password":"Exerlio@123"}'
```

`identifier` = email **or** 10-digit mobile. You get back `{"token": "...", "user": {...}}`.

### What the backend has

| Thing | Detail |
|---|---|
| Tables | 40, all `exerlio_*`. Own user table, own tokens. Django's User is not used. |
| Routes | 96 under `/api/exerlio/v1/` |
| Seed | Demo user Akif + 16 people, 11 clubs, 7 events, 17 challenges, 23-day streak, runs with GPS routes around Guntur, posts, reels, stories, chats, notifications |
| Meal scan | Gemini → Groq backup → clearly marked sample. Allergy warnings + "too much carbs/fat for one meal" warnings |
| Health data | Only from Apple Health / Health Connect. Seed vitals are marked as sample. No fake live heart rate. |

---

## Part 2 — Flutter app

### 1. Copy files

| From `flutter/` | To your project |
|---|---|
| `lib/` | replace |
| `assets/fonts/` | copy (Inter font, bundled — works offline) |
| `pubspec.yaml` | replace (keep your `name:` if different) |
| `analysis_options.yaml` | replace |
| `android/app/src/main/AndroidManifest.xml` | replace |
| `android/app/src/debug/AndroidManifest.xml` | add (allows `http://` only in debug builds) |
| `android/.../MainActivity.kt` | replace — now `FlutterFragmentActivity` (Health Connect needs it). Keep your own `package` line. |
| `ios/Runner/Info.plist` | replace (or merge the usage keys) |
| `ios/Runner/Runner.entitlements` | add (HealthKit) |
| `test/screens_smoke_test.dart` | optional — renders all screens against your server |

### 2. Android: set minSdk 26

`android/app/build.gradle.kts` (or `build.gradle`):

```kotlin
defaultConfig {
    minSdk = 26          // Health Connect needs 26+
    targetSdk = 35
}
```

### 3. iOS: turn on HealthKit

Open `ios/Runner.xcworkspace` in Xcode → **Runner** target → **Signing & Capabilities** → **+ Capability** → **HealthKit**. Also add **Background Modes** → tick **Location updates**.

In `ios/Podfile` set `platform :ios, '14.0'`.

### 4. Get packages and run

```bash
flutter pub get
flutter run --dart-define=EXERLIO_API=https://api.chandus7.in/api/exerlio/v1 --dart-define=EXERLIO_DEMO=true
```

| Flag | Meaning |
|---|---|
| `EXERLIO_API` | Your server. Default is `http://10.0.2.2:8000/...` (laptop + Android emulator). |
| `EXERLIO_DEMO=true` | Shows "Use the demo account" on login. **Leave it out for store builds.** |

### 5. Store builds

```bash
# Android (Play Store)
flutter build appbundle --release --dart-define=EXERLIO_API=https://api.chandus7.in/api/exerlio/v1

# iOS (App Store) — on a Mac
flutter build ipa --release --dart-define=EXERLIO_API=https://api.chandus7.in/api/exerlio/v1
```

---

## Store checklist (do these before you submit)

| Store | Item | Why |
|---|---|---|
| Play | Fill the **Health apps** declaration for the 7 Health Connect read permissions | Play rejects apps that ask for health data without it |
| Play | Location permission declaration: "records route during a workout you start" | Foreground-service location needs a reason |
| Play + App Store | Privacy policy URL (the app shows `exerlio.in/legal`) | Required for health, camera, location |
| App Store | App Privacy labels: Health & Fitness, Location, Photos, Contact info (email) | Required |
| App Store | Account deletion works in-app (Settings → Delete account) | Done — Apple requires it |
| Both | Pro subscription: billing is **not wired**. Hide Pro or add store billing before charging | Apple/Google require in-app purchase for digital subscriptions |
| Both | Push notifications not wired yet — reminders show inside the app (Nudges) | Needs Firebase (Android) + APNs key (iOS) |

---

## Folder map (Flutter)

```
lib/
├── main.dart              start, theme, login gate, toast
├── core/                  api, app_state, theme, ui kit, charts, format, device (health, voice, share, wakelock)
└── features/
    ├── auth/              welcome, sign up, log in, forgot password
    ├── onboarding/        15-step setup (goal, sports, body, allergies, health) + redo
    ├── shell/             bottom nav: Home · Train · Log + · Clubs · Profile
    ├── home/              Dashboard + Social tabs, stories row
    ├── train/             week plan, injuries, Exhaust Mode, track tab, library, session
    ├── live/              live GPS / sets / Hyrox recording, summary, offline retry
    ├── activity/          activity detail (route, splits, HR zones), all routes
    ├── recovery/          recovery score, check-in, 10-min recovery session
    ├── streak/            streak, rest-day passes
    ├── meal/              scan (Gemini), saved meals, left today, eating-out plan, race fuel
    ├── log/               Log + sheet (meal, water, weight, manual meal)
    ├── challenges/        list, detail + board, create, invite
    ├── clubs/             clubs, club page, events, new club
    ├── social/            feed, posts, comments, share, stories, reels, compose
    ├── people/            person page, followers / following / requests, find friends
    ├── messages/          inbox, conversation (live refresh)
    ├── notifications/     nudges + water + activity feed
    ├── profile/           profile tabs, edit profile
    └── settings/          settings, Pro, connected devices
```

---

## Checked before handover

| Check | Result |
|---|---|
| Backend: every endpoint called as demo user + new user (Postgres 16) | Pass. Only "fail" is by design: a consistency challenge can't be logged until workout + diet + recovery are done |
| Upgrade path v2 → v3 on Postgres (migrate + seed) | Pass |
| `flutter analyze` | No issues |
| 101 screen renders (every screen, light + dark, 390 × 844) against the seeded server | No crashes, no overflows |

**Not built (honest list):** Google/Apple sign-in, Pro payments, push notifications, Telugu/Hindi text, direct Garmin/Fitbit/Strava links (they reach Exerlio through Apple Health / Health Connect).

---

**In short:** replace `exerlio/` → add MEDIA + EMAIL settings → `migrate` → `seed_exerlio --reset`; replace `lib/` + `assets/` + platform files → minSdk 26 + HealthKit → `flutter run --dart-define=EXERLIO_API=...`.
