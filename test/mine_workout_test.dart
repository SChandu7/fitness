// "Your own workout" on a day, against a running, seeded backend: build it, save it, see the day
// follow it, then go back to Exerlio's plan.
//
//   python manage.py seed_exerlio --reset && python manage.py runserver 0.0.0.0:8000
//   flutter test test/mine_workout_test.dart --dart-define=EXERLIO_API=http://127.0.0.1:8000/api/exerlio/v1
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness/core/api.dart';
import 'package:fitness/core/app_state.dart';
import 'package:fitness/core/theme.dart';
import 'package:fitness/features/train/mine_sheet.dart';
import 'package:fitness/features/train/session_screen.dart';

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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('build, follow and clear your own workout', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    late int day;
    await tester.runAsync(() async {
      final login = Map<String, dynamic>.from(await Api.i.post('auth/login/', {'identifier': 'akif@exerlio.in', 'password': 'Exerlio@123'}) as Map);
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({'exerlio.token': login.s('token')});
      app = AppState();
      await app.boot();
      final plan = Map<String, dynamic>.from(await Api.i.get('train/plan/') as Map);
      day = plan.l('week').firstWhere((w) => !w.b('rest') && !w.b('done')).i('i');
      try {
        await Api.i.delete('train/day/$day/mine/');
      } on ApiError catch (_) {}
    });

    await tester.pumpWidget(wrap(SessionScreen(weekday: day)));
    await settle(tester);
    expect(find.text('YOUR OWN WORKOUT'), findsOneWidget);
    expect(find.text("Exerlio's plan".toUpperCase()), findsOneWidget);

    // Open the builder.
    await tester.tap(find.descendant(of: find.byType(MineCard), matching: find.byIcon(Icons.add_rounded)));
    await settle(tester);
    final fields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
    expect(fields, findsNWidgets(5));

    // A bad row is refused with a reason.
    await tester.enterText(fields.at(1), 'Bench press');
    await tester.enterText(fields.at(2), '0');
    await tester.enterText(fields.at(3), '10');
    await tester.tap(find.text('Add exercise'));
    await tester.pump();
    expect(find.text('Sets should be between 1 and 20.'), findsOneWidget);

    // Two good rows.
    await tester.enterText(fields.at(0), 'Chest, my way');
    await tester.enterText(fields.at(2), '3');
    await tester.enterText(fields.at(4), '40');
    await tester.tap(find.text('Add exercise'));
    await tester.pump();
    await tester.enterText(fields.at(1), 'Push-ups');
    await tester.enterText(fields.at(2), '3');
    await tester.enterText(fields.at(3), '15');
    await tester.tap(find.text('Add exercise'));
    await tester.pump();
    // scoped to the sheet: today's planned session behind it can list the same exercise
    Finder inSheet(String t) => find.descendant(of: find.byType(BottomSheet), matching: find.text(t));
    expect(inSheet('Bench press'), findsOneWidget);
    expect(inSheet('Push-ups'), findsOneWidget);
    expect(find.text('3 × 15 · bodyweight'), findsOneWidget);
    expect(find.text('1,200'), findsOneWidget, reason: 'volume total 3 × 10 × 40');

    final save = find.textContaining("'s workout").last;
    await tester.scrollUntilVisible(save, 200, scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
    await tester.tap(save);
    await settle(tester);

    // The day now follows it.
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('YOUR WORKOUT · FOLLOWED'), findsOneWidget);
    expect(find.text('Chest, my way'), findsOneWidget);
    expect(find.text('1,200 kg'), findsWidgets);
    expect(find.text('53 kg'), findsOneWidget, reason: 'best est. 1RM, 40 × (1 + 10/30)');
    expect(find.text("Exerlio's plan · not followed".toUpperCase()), findsOneWidget);
    expect(find.text('Start mine'), findsOneWidget);

    // Back to Exerlio's plan.
    await tester.tap(find.descendant(of: find.byType(MineCard), matching: find.byIcon(Icons.edit_outlined)));
    await settle(tester);
    final back = find.text("Go back to Exerlio's plan");
    await tester.scrollUntilVisible(back, 200, scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
    await tester.tap(back);
    await settle(tester);
    expect(find.text('YOUR OWN WORKOUT'), findsOneWidget);
    expect(find.text('Start session'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 21));
  });
}
