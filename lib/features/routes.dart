import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import 'activity/activity_screen.dart';
import 'activity/routes_screen.dart';
import 'challenges/challenge_screen.dart';
import 'challenges/create_challenge_screen.dart';
import 'clubs/club_screen.dart';
import 'live/live_screen.dart';
import 'meal/fuel_screen.dart';
import 'meal/meal_screen.dart';
import 'meal/preplan_screen.dart';
import 'meal/scan_screen.dart';
import 'messages/messages_screens.dart';
import 'people/person_screen.dart';
import 'recovery/recovery_screen.dart';
import 'recovery/recovery_session_screen.dart';
import 'shell/shell.dart';
import 'social/compose_screen.dart';
import 'streak/streak_screen.dart';
import 'train/library_screen.dart';
import 'train/session_screen.dart';

/// One place for "open screen X" so every button navigates the same way.
class Go {
  static Future<void> session(BuildContext c, int weekday) => c.push(SessionScreen(weekday: weekday));
  static Future<void> recovery(BuildContext c) => c.push(const RecoveryScreen());
  static Future<void> recoverySession(BuildContext c) => c.push(const RecoverySessionScreen());
  static Future<void> streak(BuildContext c) => c.push(const StreakScreen());
  static Future<void> scan(BuildContext c, {String? slot, bool barcode = false, bool library = false}) =>
      c.push(ScanScreen(slot: slot, barcode: barcode, fromLibrary: library));
  static Future<void> meal(BuildContext c, {int tab = 0}) => c.push(MealScreen(tab: tab));
  static Future<void> preplan(BuildContext c) => c.push(const PreplanScreen());
  static Future<void> fuel(BuildContext c) => c.push(const FuelScreen());
  static Future<void> challenge(BuildContext c, int id) => c.push(ChallengeScreen(id: id));
  static Future<void> newChallenge(BuildContext c) => c.push(const CreateChallengeScreen());
  static Future<void> library(BuildContext c, String key) => c.push(LibraryScreen(planKey: key));
  static Future<void> activity(BuildContext c, int id) => c.push(ActivityScreen(id: id));
  static Future<void> routes(BuildContext c) => c.push(const RoutesScreen());
  static Future<void> club(BuildContext c, int id, {String tab = 'posts'}) => c.push(ClubScreen(id: id, tab: tab));
  static Future<void> person(BuildContext c, int id) {
    if (id == c.app.me.i('id')) {
      ShellNav.go(c, 3);
      return Future.value();
    }
    return c.push(PersonScreen(userId: id));
  }

  static Future<void> thread(BuildContext c, int id) => c.push(ThreadScreen(threadId: id));
  static Future<void> compose(BuildContext c, String type, {int? clubId}) => c.push(ComposeScreen(type: type, clubId: clubId));
  static void challenges(BuildContext c) => ShellNav.go(c, 1, train: 2);
  static void weekPlan(BuildContext c) => ShellNav.go(c, 1, train: 0);
  static void track(BuildContext c) => ShellNav.go(c, 1, train: 1);

  /// Start a sport from Home or Train. Strength starts today's planned session.
  static Future<void> startSport(BuildContext c, String sport) async {
    if (sport == 'strength') {
      return session(c, DateTime.now().weekday - 1);
    }
    return LiveScreen.start(c, sport: sport, title: c.app.sportLabel(sport));
  }

  /// Start a library workout (sets plan or a GPS run).
  static Future<void> startLibrary(BuildContext c, Json w) async {
    if (w.s('sport').isNotEmpty) return LiveScreen.start(c, sport: w.s('sport'), title: w.s('title'));
    final ex = w.l('exercises');
    return LiveScreen.start(c, sport: 'strength', title: w.s('title'), planKey: w.s('key'), exercises: ex);
  }
}
