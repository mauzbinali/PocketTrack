import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pockettrack/main.dart';
import 'package:pockettrack/data/repository.dart';
import 'package:pockettrack/models/records.dart';

Future<void> captureReview(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_REVIEW')) return;
  final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/review').create(recursive: true);
    await File(
      'build/review/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_REVIEW')) return;
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (await font.exists()) {
      final loader = FontLoader('Roboto');
      loader.addFont(
        Future.value(ByteData.sublistView(await font.readAsBytes())),
      );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('First-use empty state and transaction form validation', (
    tester,
  ) async {
    sqfliteFfiInit();
    late Repository repo;
    await tester.runAsync(() async {
      repo = await Repository.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      await tester.pumpWidget(PocketTrackApp(repository: repo));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('PocketTrack'), findsOneWidget);
    expect(find.text('Your month, a fresh start'), findsOneWidget);
    await captureReview(tester, 'light-home');
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Transaction'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a category'), findsOneWidget);
    expect(
      find.text('Enter an amount from 0.01 to 9,999,999,999.99'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).first, '125.50');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save transaction'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('PocketTrack'), findsOneWidget);
    await tester.runAsync(() async {
      expect((await repo.entries()).single.amount, 12550);
      final now = DateTime.now();
      expect(
        (await repo.entries()).single.date,
        DateTime(now.year, now.month - 1),
      );
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(repo.close);
  });
  testWidgets(
    'Over-budget labels and report category navigation on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      sqfliteFfiInit();
      late Repository repo;
      final now = DateTime.now();
      await tester.runAsync(() async {
        repo = await Repository.open(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        );
        await repo.saveEntry(
          Entry(
            type: 'expense',
            amount: 12000,
            categoryId: 1,
            date: DateTime(now.year, now.month, 1),
          ),
        );
        await repo.saveBudget(
          Budget(
            categoryId: 1,
            year: now.year,
            month: now.month,
            amount: 10000,
          ),
        );
        await tester.pumpWidget(PocketTrackApp(repository: repo));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budgets').last);
      await tester.pumpAndSettle();
      expect(find.text('Over budget · 120.0% used'), findsOneWidget);
      expect(find.text('PKR 20.00 over budget'), findsOneWidget);
      await tester.tap(find.text('Reports').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Food'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('1 transaction'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('1 transaction'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(repo.close);
    },
  );
  testWidgets('Search, dark theme and large amounts on a narrow display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    sqfliteFfiInit();
    late Repository repo;
    await tester.runAsync(() async {
      repo = await Repository.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      await repo.saveEntry(
        Entry(
          type: 'expense',
          amount: maxAmount,
          categoryId: 1,
          date: DateTime.now(),
          note: 'Lunch with family',
        ),
      );
      await tester.pumpWidget(PocketTrackApp(repository: repo));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    await captureReview(tester, 'dark-home-large-text');
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'unmatched');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No matching transactions'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('No matching transactions'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      -250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(find.byType(TextField), 'FAMILY');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1 transaction'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('1 transaction'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Lunch with family'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Reports').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Food'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Budgets').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FloatingActionButton, 'Budget'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(repo.close);
  });
}
