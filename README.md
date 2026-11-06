# PocketTrack

Android-only Flutter app for offline income, expenses, monthly category budgets, and reports in PKR. No login or backend. The database starts empty except for 13 default categories.

## Setup and run

Requires Flutter 3.44 or newer (Dart 3.12), Android SDK/build tools, and a compatible JDK. The project was created at:

`C:\Users\mauzb\OneDrive\Desktop\intership projects\pockettrack`

```powershell
flutter pub get
flutter doctor
# If prompted, review Android SDK licenses:
flutter doctor --android-licenses
flutter devices
flutter run -d <android-device-id>
```

Connect an Android phone with USB debugging enabled or start an Android emulator. Only the Android platform folder is included. Package downloads and builds need internet initially; normal app usage does not.

```powershell
dart format lib test integration_test
flutter analyze
flutter test
flutter test integration_test/android_test.dart -d <android-device-id>
flutter build apk --debug
# Requires your upload keystore in android/key.properties:
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-debug.apk` (or `app-release.apk`). Release builds require your upload signing key; see RELEASE.md. They no longer fall back to the development debug key.

## Features

- Tap the flask icon (**Explore demo**) to try 28 sample transactions and 10 budgets across this month and last month. Demo records use a separate temporary database and reset when you leave. Your real records are untouched.
- Home, History, Budgets, and Reports tabs with a shared month selector.
- Refined Material 3 styling, system dark mode, accessible wrapping amounts, and monthly spending insights.
- Case-insensitive transaction search across notes and category names, combined with existing filters.
- Context-aware add button: create a budget directly from the Budgets tab.
- Income/expense create, view, edit, and confirmed deletion; validation, save protection, and unsaved-change prompts.
- Combined type/category/inclusive date-range filtering. Clear filters returns to the selected month and all types/categories.
- Monthly category budgets, database-enforced uniqueness, progress and actual over-budget percentage. Budget deletion preserves transactions.
- Reports show only expenses; category taps open filtered history. Unbudgeted spending is explicitly identified.
- Amounts are integer paisa, parsed without floating-point multiplication. Maximum per record is PKR 9,999,999,999.99.

## Architecture and storage

- `lib/models/records.dart`: records, exact money parsing/formatting, filters, monthly calculations, budget statuses.
- `lib/data/repository.dart`: sqflite SQLite schema v1, category seeding, CRUD, constraints, and error mapping.
- `lib/screens/dashboard.dart`: lightweight state, navigation, totals, history, budgets, reports, details.
- `lib/screens/forms.dart`: reusable validated transaction/budget editor.
- `lib/widgets/common.dart`: month selection, cards, category icons, transaction rows, confirmation dialogs.
- `test/`: calculation, SQLite CRUD/reopen, and widget tests.

Data is saved in the app's private `pockettrack.db` database. Dates are local calendar days, and monthly totals are derived from saved records rather than separately cached totals. Schema version 1 seeds categories once. Future schema changes must increment the version and supply a preserving `onUpgrade` migration.

There is no HTTP client, account, analytics, or remote service. The main/release manifest requests no internet permission. Debug builds use Flutter's standard internet permission for development tooling. Android backup is disabled for local-only storage.

## Verification and limitations

See `VERIFICATION.md` for the actual checks performed in this environment. Tests use real SQLite on the host through sqflite_common_ffi; Android uses sqflite's native plugin. Device restart and airplane-mode checks require an Android device/emulator and are separate from host persistence tests.

No data export/import or encryption beyond Android's app sandbox is included. Uninstalling or clearing app storage removes records. Budgets never carry forward automatically. For very large histories, pagination would be a future improvement; this personal-use version loads saved records into memory.

