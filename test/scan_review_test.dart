// Meal scan review against a running, seeded backend: change an item's dish and amount,
// set the oil level, take an item off, and check the totals follow.
//
//   python manage.py seed_exerlio --reset && python manage.py runserver 0.0.0.0:8000
//   flutter test test/scan_review_test.dart --dart-define=EXERLIO_API=http://127.0.0.1:8000/api/exerlio/v1
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness/core/api.dart';
import 'package:fitness/core/app_state.dart';
import 'package:fitness/core/theme.dart';
import 'package:fitness/features/meal/scan_screen.dart';

late AppState app;

Widget wrap(Widget child) => AppScope(
      state: app,
      child: MaterialApp(
        theme: buildTheme(XC.light, Brightness.light),
        builder: (context, c) => XTheme(c: XC.light, genz: app.genz, reduceMotion: true, child: c!),
        home: child,
      ),
    );

void main() {
  setUpAll(() => HttpOverrides.global = null);

  // Network I/O only advances between frames under the test clock.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  int kcal(WidgetTester tester) => int.parse((tester.widget<Text>(find.byKey(const Key('scan-total-kcal')))).data!);

  testWidgets('change dish, amount, oil and remove on the scan review', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    late Json scan;
    await tester.runAsync(() async {
      final login = Map<String, dynamic>.from(await Api.i.post('auth/login/', {'identifier': 'akif@exerlio.in', 'password': 'Exerlio@123'}) as Map);
      SharedPreferences.setMockInitialValues({'exerlio.token': login.s('token')});
      app = AppState();
      await app.boot();
      final photo = File('${Directory.systemTemp.path}/exerlio_scan_test.jpg')..writeAsBytesSync(List.filled(256, 7));
      scan = Map<String, dynamic>.from(await Api.i.upload('meals/scan/', fields: {'kind': 'plate'}, files: {'image': photo}) as Map);
    });

    await tester.pumpWidget(wrap(ScanScreen(result: scan)));
    await settle(tester);
    final start = kcal(tester);
    expect(scan.b('asks_oil'), isTrue, reason: 'sample plates have oily dishes');
    await tester.scrollUntilVisible(find.text('Oil / ghee'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Oil / ghee'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('scan-total-kcal')), -400, scrollable: find.byType(Scrollable).first);

    // 1. Change the first item: more of it, and a different dish from the catalogue.
    final first = scan.l('items').first;
    await tester.tap(find.text(first.s('name')));
    await settle(tester);
    expect(find.text('AMOUNT'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.enterText(find.byType(TextField), 'dal tadka');
    await tester.pump();
    await tester.tap(find.text('Dal tadka').last);
    await tester.pump();
    await tester.tap(find.text('Use this'));
    await settle(tester);
    expect(find.text('Dal tadka'), findsOneWidget, reason: 'item renamed to the picked dish');
    expect(find.textContaining('changed'), findsWidgets);
    final afterEdit = kcal(tester);
    expect(afterEdit, isNot(start));

    // 2. Heavy oil raises calories on oily dishes.
    await tester.scrollUntilVisible(find.text('Heavy'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Heavy'));
    await settle(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('scan-total-kcal')), -400, scrollable: find.byType(Scrollable).first);
    expect(kcal(tester), greaterThan(afterEdit));

    // 3. Take an item off the plate and put it back.
    await tester.scrollUntilVisible(find.byKey(const Key('scan-total-kcal')), -400, scrollable: find.byType(Scrollable).first);
    final heavy = kcal(tester);
    await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded).first);
    await settle(tester);
    expect(kcal(tester), lessThan(heavy));
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded).first);
    await settle(tester);
    expect(kcal(tester), heavy);

    // 4. Undo the edit.
    await tester.tap(find.text('Dal tadka'));
    await settle(tester);
    await tester.tap(find.text('Undo my changes'));
    await settle(tester);
    expect(find.text(first.s('name')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 21));
  });
}
