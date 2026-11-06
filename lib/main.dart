import 'package:flutter/material.dart';
import 'data/repository.dart';
import 'screens/dashboard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PocketTrackApp());
}

class PocketTrackApp extends StatelessWidget {
  final Repository? repository;
  const PocketTrackApp({super.key, this.repository});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PocketTrack',
    debugShowCheckedModeBanner: false,
    theme: appTheme(Brightness.light),
    darkTheme: appTheme(Brightness.dark),
    home: Dashboard(repository: repository),
  );
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF176B51),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF101B18)
        : const Color(0xFFF3F6F2),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF101B18) : const Color(0xFFF3F6F2),
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF1A2823) : Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.all(18),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}
