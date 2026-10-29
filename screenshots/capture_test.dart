// App Store screenshots (iPhone 6.3", 1206x2622) rendered from the real screens
// against the live API, logged in as the demo account.
//
//   flutter test screenshots/capture_test.dart
//
// PNGs are written to screenshots/ios/. Not part of the normal test run.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness/core/api.dart';
import 'package:fitness/core/app_state.dart';
import 'package:fitness/core/theme.dart';
import 'package:fitness/features/activity/activity_screen.dart';
import 'package:fitness/features/challenges/challenge_screen.dart';
import 'package:fitness/features/clubs/clubs_screen.dart';
import 'package:fitness/features/meal/meal_screen.dart';
import 'package:fitness/features/recovery/recovery_screen.dart';
import 'package:fitness/features/shell/shell.dart';
import 'package:fitness/features/train/train_screen.dart';

late AppState app;
final shotKey = GlobalKey();

Widget wrap(Widget child) => RepaintBoundary(
      key: shotKey,
      child: AppScope(
        state: app,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(XC.light, Brightness.light),
          builder: (context, c) => XTheme(c: XC.light, genz: app.genz, reduceMotion: true, child: c!),
          home: child,
        ),
      ),
    );

Future<Json> getJ(String path) async => Map<String, dynamic>.from(await Api.i.get(path) as Map);

Future<void> loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(File(f).readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await loadFont('Inter', [for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/Inter-$w.ttf']);
    final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    await loadFont('MaterialIcons', ['$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
  });

  testWidgets('store screenshots', (tester) async {
    // 402 x 874 points at 3x = 1206 x 2622 (the size App Store Connect asks for), with iPhone safe areas.
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    FlutterError.onError = (_) {};

    late int chId, actId;
    await tester.runAsync(() async {
      final login = Map<String, dynamic>.from(await Api.i.post('auth/login/', {'identifier': 'akif@exerlio.in', 'password': 'Exerlio@123'}) as Map);
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({'exerlio.token': login.s('token')});
      app = AppState();
      await app.boot();
      chId = (await getJ('challenges/?tab=active')).l('items').first.i('id');
      actId = (await getJ('activities/?gps=1')).l('items').first.i('id');
    });

    final shots = <String, Widget>{
      '1_home': const Shell(),
      '2_train': const TrainScreen(),
      '3_activity': ActivityScreen(id: actId),
      '4_meal': const MealScreen(tab: 2),
      '5_recovery': const RecoveryScreen(),
      '6_challenge': ChallengeScreen(id: chId),
      '7_clubs': const ClubsScreen(),
    };

    Directory('screenshots/ios').createSync(recursive: true);
    for (final e in shots.entries) {
      await tester.pumpWidget(wrap(e.value));
      // Network I/O only advances between frames under the test clock, so give it many short ones.
      for (var i = 0; i < 80; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 120)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.runAsync(() async {
        final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('screenshots/ios/${e.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 25));
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
