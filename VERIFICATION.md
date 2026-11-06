# Verification - 6 November 2026

## Current review

- Demo-data follow-up: nine host tests pass and analysis is clean. Added tests for sample totals, budget status variety, year boundaries, no future dates, duplicate prevention, and preserving existing records. The flask action opens a separate temporary demo database.
- `flutter analyze`: no issues found. `dart format lib test integration_test` completed.
- Reviewed all six application Dart files, unit/widget/integration tests, Android activity, manifests, Gradle configuration, styles, and drawable resources. Generated files and dependency/build outputs were not treated as authored source.
- Seven host tests pass. Coverage includes money parsing, calculations and filters, SQLite CRUD and reopen persistence, calendar-day validation, stale-update detection, form validation/save, budget reporting, search, dark mode, maximum amounts, and large text at 360 pixels.
- Optional screenshot capture: `flutter test --dart-define=CAPTURE_REVIEW=true`. Visually reviewed light and dark home renders in `build/review`. Windows capture uses Segoe UI as a test font; these are layout previews, not device screenshots or store assets.
- Android debug APK builds successfully. Output: `build/app/outputs/flutter-apk/app-debug.apk`.
- Release build was attempted and correctly refused to proceed without `android/key.properties`. No store-ready signed release was produced. Existing older release artifacts must not be mistaken for this version.
- Native integration test was attempted but could not run: no Android device/emulator is connected. The earlier device results below describe the older app only.
- No dependencies were changed and the database schema remains version 1. Existing data is preserved.

## Remaining limits

Configure the upload keystore and run device verification before publication. No claim of universal bug-free behavior is made. Export/import, encrypted database storage, and pagination are not implemented. See RELEASE.md for upload preparation.

---

## Historical verification (previous version; not rerun on device)

# Verification — 2 November 2026

Environment: Flutter 3.44.1, Dart 3.12.1, Windows host, Pixel 7 Android emulator.

## Passed

- `dart format lib test integration_test`.
- `flutter analyze`: no issues found.
- `flutter test`: 5 passing tests covering exact integer-paisa parsing, inclusive combined filters, month boundaries, monthly/category totals, empty months, all budget status thresholds, SQLite transaction CRUD, type/category integrity, duplicate budget prevention, budget editing/deletion, existing spending in new budgets, transaction moves between months/categories/types, and persistence after closing/reopening the database.
- Widget checks: first-use empty state, field validation, saving a transaction through the form, over-budget amount/percentage, report-category navigation, and layout on a 360-pixel-wide viewport. A discovered app-bar overflow was corrected and the suite rerun successfully.
- `flutter test integration_test/android_test.dart -d emulator-5554`: 1 passing native Android integration test. Verified native SQLite writes, close/reopen persistence, UI using persisted budgets/transactions, over-budget display, and deletion preserving unrelated records.
- The native Android integration test ran with Wi-Fi and mobile data disabled (`wifi_on=0`, `mobile_data=0`). Both were restored afterward. The first run stalled during emulator startup; a rerun with diagnostic stages and bounded waits passed.
- Android debug and release APK builds passed. Final release APK: approximately 48.5 MB, built from lib/main.dart.

## Test data and limits

Host tests use temporary SQLite databases; native tests use a separate `pockettrack_verification.db` and delete it afterward. No fictional transactions are inserted into the real `pockettrack.db`.

Persistence was tested through database closure/reopening, including on Android. A physical-device reboot or OS process-death persistence test was not performed. Full manual interaction with every edit/delete/filter combination on a physical phone was not performed. Database tests cover these operations; widget tests cover the selected UI flows above.

The release build uses the generated development signing key and is intended for local installation/testing, not Play Store publication. Configure release signing before distribution. Android SDK doctor reports some unaccepted optional SDK licenses, but the tested Android builds and native test succeeded.

## Repeat

```powershell
flutter pub get
dart format lib test integration_test
flutter analyze
flutter test
flutter test integration_test/android_test.dart -d <android-device-id>
flutter build apk --release
```

