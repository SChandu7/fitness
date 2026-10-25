// Renders every screen, light and dark, at 390x844 against a running, seeded backend.
//
//   python manage.py seed_exerlio --reset && python manage.py runserver 0.0.0.0:8000
//   flutter test --dart-define=EXERLIO_API=http://127.0.0.1:8000/api/exerlio/v1
//
// Fails on any exception or layout overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness/core/api.dart';
import 'package:fitness/core/app_state.dart';
import 'package:fitness/core/theme.dart';
import 'package:fitness/features/activity/activity_screen.dart';
import 'package:fitness/features/activity/routes_screen.dart';
import 'package:fitness/features/auth/forgot_screen.dart';
import 'package:fitness/features/auth/login_screen.dart';
import 'package:fitness/features/auth/signup_screen.dart';
import 'package:fitness/features/auth/welcome_screen.dart';
import 'package:fitness/features/challenges/challenge_screen.dart';
import 'package:fitness/features/challenges/create_challenge_screen.dart';
import 'package:fitness/features/clubs/club_screen.dart';
import 'package:fitness/features/clubs/clubs_screen.dart';
import 'package:fitness/features/clubs/new_club_screen.dart';
import 'package:fitness/features/home/home_screen.dart';
import 'package:fitness/features/live/summary_screen.dart';
import 'package:fitness/features/meal/fuel_screen.dart';
import 'package:fitness/features/meal/meal_screen.dart';
import 'package:fitness/features/meal/preplan_screen.dart';
import 'package:fitness/features/meal/scan_screen.dart';
import 'package:fitness/features/messages/messages_screens.dart';
import 'package:fitness/features/notifications/notifications_screen.dart';
import 'package:fitness/features/onboarding/onboarding_screen.dart';
import 'package:fitness/features/people/find_friends_screen.dart';
import 'package:fitness/features/people/person_screen.dart';
import 'package:fitness/features/people/social_list_screen.dart';
import 'package:fitness/features/profile/profile_screen.dart';
import 'package:fitness/features/recovery/recovery_screen.dart';
import 'package:fitness/features/recovery/recovery_session_screen.dart';
import 'package:fitness/features/settings/devices_screen.dart';
import 'package:fitness/features/settings/settings_screen.dart';
import 'package:fitness/features/shell/shell.dart';
import 'package:fitness/features/social/compose_screen.dart';
import 'package:fitness/features/social/reels_screen.dart';
import 'package:fitness/features/streak/streak_screen.dart';
import 'package:fitness/features/train/library_screen.dart';
import 'package:fitness/features/train/session_screen.dart';
import 'package:fitness/features/train/train_screen.dart';

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
  final errors = <String>[];
  setUpAll(() async {
    HttpOverrides.global = null;
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 800)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 100));
    final lists = find.byType(Scrollable);
    for (var i = 0; i < 6 && lists.evaluate().isNotEmpty; i++) {
      await tester.drag(lists.first, const Offset(0, -700), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('every screen renders against the live API', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    final orig = FlutterError.onError;
    var current = '';
    FlutterError.onError = (d) {
      final msg = d.exceptionAsString();
      if (msg.contains('google_fonts') || msg.contains('Failed to load font') || msg.contains('path_provider')) return;
      if (msg.contains('HTTP request failed') || msg.contains('NetworkImage')) return;
      if (msg.contains('overflowed')) {
        final info = d.toString();
        final i = info.indexOf('The relevant error-causing widget was');
        errors.add('[$current] OVERFLOW ${i >= 0 ? info.substring(i, (i + 260).clamp(0, info.length)).replaceAll('\n', ' ') : msg}');
        return;
      }
      errors.add('[$current] ${msg.split('\n').first}');
    };

    late int chId, threadId, clubId, privateClubId, publicPerson, privatePerson, actId;
    late Json summary;
    late List<Json> reels;
    await tester.runAsync(() async {
      final login = Map<String, dynamic>.from(await Api.i.post('auth/login/', {'identifier': 'akif@exerlio.in', 'password': 'Exerlio@123'}) as Map);
      SharedPreferences.setMockInitialValues({'exerlio.token': login.s('token')});
      app = AppState();
      await app.boot();
      chId = (await getJ('challenges/?tab=active')).l('items').first.i('id');
      threadId = (await getJ('threads/')).l('items').first.i('id');
      final clubs = (await getJ('clubs/')).l('items');
      clubId = clubs.first.i('id');
      privateClubId = clubs.firstWhere((c) => c.b('is_private'), orElse: () => clubs.last).i('id');
      publicPerson = (await getJ('social/?tab=following')).l('items').first.i('id');
      final people = (await getJ('people/')).l('items');
      privatePerson = people.firstWhere((p) => p.b('is_private'), orElse: () => people.first).i('id');
      actId = (await getJ('activities/?gps=1')).l('items').first.i('id');
      summary = {'activity': await getJ('activities/$actId/'), 'prs': const [], 'finished': const []};
      final r = await Api.i.get('reels/');
      reels = r is Map ? Map<String, dynamic>.from(r).l('items') : [for (final x in r as List) Map<String, dynamic>.from(x as Map)];
    });

    final screens = <String, Widget>{
      'Shell': const Shell(),
      'Home': const HomeScreen(),
      'Train': const TrainScreen(),
      'Session today': SessionScreen(weekday: DateTime.now().weekday - 1),
      'Session Mon': const SessionScreen(weekday: 0),
      'Library': const LibraryScreen(planKey: 'lib-upper'),
      'Library run': const LibraryScreen(planKey: 'lib-run5k'),
      'Recovery': const RecoveryScreen(),
      'Recovery session': const RecoverySessionScreen(),
      'Streak': const StreakScreen(),
      'Activity': ActivityScreen(id: actId),
      'Routes': const RoutesScreen(),
      'Summary': SummaryScreen(result: summary),
      'Meal scan tab': const MealScreen(),
      'Meal saved': const MealScreen(tab: 1),
      'Meal left': const MealScreen(tab: 2),
      'Scan': const ScanScreen(),
      'Preplan': const PreplanScreen(),
      'Fuel': const FuelScreen(),
      'Challenge': ChallengeScreen(id: chId),
      'Create challenge': const CreateChallengeScreen(),
      'Clubs': const ClubsScreen(),
      'Club': ClubScreen(id: clubId),
      'Club events': ClubScreen(id: clubId, tab: 'events'),
      'Club board': ClubScreen(id: clubId, tab: 'board'),
      'Club private': ClubScreen(id: privateClubId),
      'New club': const NewClubScreen(),
      'Compose post': const ComposeScreen(type: 'post'),
      'Compose reel': const ComposeScreen(type: 'reel'),
      'Compose story': const ComposeScreen(type: 'story'),
      'Compose event': const ComposeScreen(type: 'event'),
      if (reels.isNotEmpty) 'Reels': ReelsScreen(reels: reels),
      'Messages': const MessagesScreen(),
      'Thread': ThreadScreen(threadId: threadId),
      'Notifications': const NotificationsScreen(),
      'Notifications activity': const NotificationsScreen(seg: 1),
      'Profile': const ProfileScreen(),
      'Social followers': const SocialListScreen(),
      'Social requests': const SocialListScreen(tab: 'requests'),
      'Find friends': const FindFriendsScreen(),
      'Person public': PersonScreen(userId: publicPerson),
      'Person private': PersonScreen(userId: privatePerson),
      'Settings': const SettingsScreen(),
      'Pro': const ProScreen(),
      'Devices': const DevicesScreen(),
      'Onboarding redo': const OnboardingScreen(redo: true),
    };

    for (final dark in [false, true]) {
      for (final e in screens.entries) {
        current = '${e.key}${dark ? ' (dark)' : ''}';
        await tester.pumpWidget(wrap(e.value, dark: dark));
        await settle(tester);
        final ex = tester.takeException();
        if (ex != null) errors.add('[$current] EXCEPTION $ex');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      }
    }

    for (final t in ['progress', 'posts', 'reels', 'saved', 'badges']) {
      current = 'Profile $t';
      ShellNav.profileTab.value = t;
      await tester.pumpWidget(wrap(const ProfileScreen()));
      await settle(tester);
      final ex = tester.takeException();
      if (ex != null) errors.add('[$current] EXCEPTION $ex');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }

    await tester.runAsync(() async => app.logout(silent: true));
    for (final e in {'Welcome': const WelcomeScreen(), 'Login': const LoginScreen(), 'Signup': const SignupScreen(), 'Forgot': const ForgotScreen()}.entries) {
      current = e.key;
      await tester.pumpWidget(wrap(e.value));
      await tester.pump(const Duration(milliseconds: 300));
      final ex = tester.takeException();
      if (ex != null) errors.add('[$current] EXCEPTION $ex');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }

    // A request still in flight over a slow link leaves its 20 s timeout timer pending; let it expire.
    await tester.pump(const Duration(seconds: 21));
    FlutterError.onError = orig;
    // ignore: avoid_print
    print('SCREENS CHECKED: ${screens.length * 2 + 9}');
    for (final e in errors.toSet()) {
      // ignore: avoid_print
      print('ERR $e');
    }
    expect(errors, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
