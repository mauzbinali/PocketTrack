# PocketTrack release preparation

## Changes in this review

- Refreshed Material 3 surfaces, filled inputs, gradient balance card, and automatic system dark mode.
- Added transaction search by note/category, daily spending averages, income usage, and comparison with the full previous month.
- Improved transaction amount wrapping, report amounts, input errors, and narrow-screen layouts.
- Budgets tab now offers a budget action in its floating button. Switching tabs starts at the top of the selected page.
- Fixed calendar-day validation: a transaction with today's time is accepted, while future days and dates before 1900 are rejected.
- New transactions respect a selected past month, and saving switches to the record's month and clears history filters so it is easy to find.
- Stale transaction and budget updates now fail instead of falsely reporting success.
- Added lifecycle checks, owned database cleanup, and guards against repeated discard/delete dialogs.
- Release signing uses an upload keystore rather than silently using the debug key.

## Create the upload artifact

1. Keep your existing upload keystore if this app has already been published. Otherwise create an upload keystore following the official guide below and store a secure backup.
2. Copy `android/key.properties.example` to `android/key.properties`. Fill in your own keystore path, alias, and passwords. These files and keystores are ignored by Git. Do not share them.
3. Confirm that `com.pockettrack.pockettrack` is the intended application ID before first publication. Do not change it for an update to an existing listing.
4. Set a higher build number in `pubspec.yaml` if version code 1 has already been uploaded.
5. Run `flutter analyze`, `flutter test`, and the Android integration test on a connected device.
6. Run `flutter build appbundle --release`. The output is `build/app/outputs/bundle/release/app-release.aab`.

Signing reference: https://docs.flutter.dev/deployment/android

## Checks still needed before publication

- Configure the real signing credentials. None were generated or committed during this review.
- Test on an Android phone: keyboard, back navigation, create/edit/delete, month/date filters, dark mode, and closing/reopening the app.
- Prepare store screenshots, description, and privacy information that accurately describe offline-only storage.
- Data remains local and backup is disabled. Uninstalling or clearing storage deletes records. Export/import is not implemented.
- Large histories are loaded into memory; pagination remains a future improvement.

See `VERIFICATION.md` for checks actually performed. A passing test suite does not guarantee the absence of every possible bug.
