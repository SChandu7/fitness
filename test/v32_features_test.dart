// The 3.2 features against a running, seeded backend: event prep, exercise demo, women's health,
// focus poster and the settings categories. Light and dark, 390x844, fails on exceptions or overflow.
//
//   python manage.py seed_exerlio --reset && python manage.py runserver 127.0.0.1:8000
//   flutter test test/v32_features_test.dart --dart-define=EXERLIO_API=http://127.0.0.1:8000/api/exerlio/v1
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness/core/api.dart';
import 'package:fitness/core/app_state.dart';
import 'package:fitness/core/theme.dart';
import 'package:fitness/core/ui.dart';
import 'package:fitness/features/home/focus_poster.dart';
import 'package:fitness/features/settings/settings_screen.dart';
import 'package:fitness/features/settings/womens_health_screen.dart';
import 'package:fitness/features/train/event_prep.dart';
import 'package:fitness/features/train/exercise_demo.dart';

late AppState app;

Widget wrap(Widget child, {bool dark = false}) => AppScope(
      state: app,
      child: MaterialApp(
        theme: buildTheme(dark ? XC.dark : XC.light, dark ? Brightness.dark : Brightness.light),
        builder: (context, c) => XTheme(c: dark ? XC.dark : XC.light, genz: app.genz, reduceMotion: true, child: c!),
        home: child,
      ),
    );

Future<Json> getJ(String path) async => Map<String, dynamic>.from(await Api.i.get(path) as Map);

void main() {
  setUpAll(() => HttpOverrides.global = null);

  testWidgets('3.2 features render and respond', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    final errors = <String>[];
    final orig = FlutterError.onError;
    var current = '';
    FlutterError.onError = (d) {
      final msg = d.exceptionAsString();
      if (msg.contains('google_fonts') || msg.contains('Failed to load font') || msg.contains('path_provider')) return;
      if (msg.contains('HTTP request failed') || msg.contains('NetworkImage')) return;
      if (msg.contains('overflowed')) {
        final info = d.toString();
        final i = info.indexOf('The relevant error-causing widget was');
        errors.add('[$current] OVERFLOW ${i >= 0 ? info.substring(i, (i + 300).clamp(0, info.length)).replaceAll('\n', ' ') : msg}');
        return;
      }
      errors.add('[$current] ${msg.split('\n').first}');
    };

    Future<void> net([int ms = 700]) async {
      // real time for the HTTP call, then frames for the route or sheet it opens
      for (var k = 0; k < 4; k++) {
        await tester.runAsync(() => Future.delayed(Duration(milliseconds: ms ~/ 2)));
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    void want(Finder f, String what, [int? n]) {
      final got = f.evaluate().length;
      if (n == null ? got == 0 : got != n) errors.add('[$current] expected $what, found $got');
    }

    Future<void> reset() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    void check() {
      // ignore: avoid_print
      print('ok? $current');
      final ex = tester.takeException();
      if (ex != null) errors.add('[$current] EXCEPTION $ex');
    }

    try {
      late Json event, poster;
      await tester.runAsync(() async {
        final login = Map<String, dynamic>.from(await Api.i.post('auth/login/', {'identifier': 'akif@exerlio.in', 'password': 'Exerlio@123'}) as Map);
        SharedPreferences.setMockInitialValues({'exerlio.token': login.s('token')});
        // Local test database only: the seeded user becomes a female profile so women's health opens.
        app = AppState();
        await app.boot();
        await Api.i.patch('me/', {'sex': 'female'});
        await app.refreshMe();
        final d = DateTime.now().add(const Duration(days: 20));
        await Api.i.post('train/event/', {
          'name': 'City 10K',
          'kind': 'running',
          'date': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          'level': 'intermediate',
          'target': 'under 55 min',
          'days_per_week': 4,
        });
        event = (await getJ('train/event/')).m('event');
        poster = (await getJ('home/')).m('poster');
      });
      if (event.s('name') != 'City 10K' || event.i('days_left') != 20) errors.add('event saved wrong: $event');
      // ignore: avoid_print
      print('setup done: ${event.s('phase')} / ${poster.s('title')}');

      for (final dark in [false, true]) {
        final tag = dark ? ' (dark)' : '';

        await reset();
        current = 'Event card empty$tag';
        await tester.pumpWidget(wrap(const Scaffold(body: SingleChildScrollView(child: EventPrepCard(null))), dark: dark));
        await tester.pump();
        want(find.text('Got an event coming up?'), "find.text('Got an event coming up?')", 1);
        check();

        await reset();
        current = 'Event card$tag';
        await tester.pumpWidget(wrap(Scaffold(body: SingleChildScrollView(child: EventPrepCard(event))), dark: dark));
        await tester.pump();
        want(find.text('20'), "find.text('20')", 1);
        want(find.text('days to go'), "find.text('days to go')", 1);
        check();

        current = 'Event schedule$tag';
        await tester.tap(find.text('Next 7 days'));
        await net();
        await tester.pump(const Duration(milliseconds: 400));
        want(find.text('Next 7 days'), "find.text('Next 7 days')", 2);
        check();

        await reset();
        current = 'Event form$tag';
        await tester
            .pumpWidget(wrap(Scaffold(body: Builder(builder: (ctx) => Center(child: XButton('open', onTap: () => showEventForm(ctx, event))))), dark: dark));
        await tester.tap(find.text('open'));
        await tester.pump(const Duration(milliseconds: 400));
        want(find.text('Your event'), "find.text('Your event')", 1);
        check();

        await reset();
        current = 'Exercise demo$tag';
        await tester.pumpWidget(
            wrap(Scaffold(body: Builder(builder: (ctx) => Center(child: XButton('demo', onTap: () => showExerciseDemo(ctx, 'Goblet squat'))))), dark: dark));
        await tester.tap(find.text('demo'));
        await net();
        await tester.pump(const Duration(milliseconds: 400));
        want(find.text('KEY FORM CUES'), "find.text('KEY FORM CUES')", 1);
        want(find.byType(MovementFigure), 'find.byType(MovementFigure)', 1);
        check();

        await reset();
        current = 'Focus poster$tag';
        await tester.pumpWidget(wrap(Scaffold(body: SingleChildScrollView(child: FocusPoster(poster))), dark: dark));
        await tester.pump();
        want(find.text('YOUR FOCUS TODAY'), "find.text('YOUR FOCUS TODAY')", 1);
        check();

        await reset();
        current = "Women's health$tag";
        await tester.pumpWidget(wrap(const WomensHealthScreen(), dark: dark));
        await net();
        if (find.text("Turn on women's health support").evaluate().isNotEmpty) {
          await tester.tap(find.text("Turn on women's health support"));
          await net();
        }
        if (find.byType(Scrollable).evaluate().isNotEmpty) {
          await tester.scrollUntilVisible(find.text('ENERGY TODAY'), 200, scrollable: find.byType(Scrollable).first, maxScrolls: 20);
        }
        want(find.text('ENERGY TODAY'), "find.text('ENERGY TODAY')", 1);
        check();

        await reset();
        current = 'Settings$tag';
        await tester.pumpWidget(wrap(const SettingsScreen(), dark: dark));
        await net();
        for (final title in ['Personal profile', 'Preferences', 'Goals and targets', 'Nutrition and scanning', 'Privacy and safety', 'Support']) {
          current = 'Settings › $title$tag';
          await tester.scrollUntilVisible(find.text(title), 200, scrollable: find.byType(Scrollable).first);
          await tester.tap(find.text(title));
          await tester.pump(const Duration(milliseconds: 500));
          check();
          tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
          await tester.pump(const Duration(milliseconds: 500));
        }
        current = 'Settings search$tag';
        await tester.scrollUntilVisible(find.byType(TextField), -300, scrollable: find.byType(Scrollable).first);
        await tester.enterText(find.byType(TextField).first, 'allerg');
        await tester.pump();
        want(find.text('No settings match "allerg".'), 'find.text(\'No settings match "allerg".\')', 0);
        check();

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      }

      // put the seed back the way it was
      await tester.runAsync(() async {
        await Api.i.delete('train/event/');
        await Api.i.patch('me/', {'sex': 'male'});
      });
      await tester.pump(const Duration(seconds: 21));
    } catch (e, st) {
      errors.add('[$current] THREW $e ${st.toString().split(String.fromCharCode(10)).take(4).join(' | ')}');
    } finally {
      FlutterError.onError = orig;
    }
    for (final e in errors.toSet()) {
      // ignore: avoid_print
      print('ERR $e');
    }
    expect(errors, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
