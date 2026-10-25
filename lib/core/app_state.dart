import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'format.dart';

/// Session + app-wide preferences. Screen data is NOT kept here —
/// each screen loads its own data from the API.
class AppState extends ChangeNotifier {
  static const _kToken = 'exerlio.token';
  static const _kMode = 'exerlio.mode';
  static const _kTheme = 'exerlio.theme';
  static const _kCatalog = 'exerlio.catalog';

  SharedPreferences? prefs;
  bool ready = false;
  String? token;
  Json me = {};
  Json catalog = {};
  String mode = 'classic';
  ThemeMode _theme = ThemeMode.system;

  /// Bumped after any write so open screens reload their data.
  int version = 0;

  String toast = '';
  int _toastId = 0;

  bool get loggedIn => token != null;
  bool get onboarded => me.b('onboarded');
  bool get genz => mode == 'genz';
  Json get settings => me.m('settings');
  bool setting(String key, [bool fallback = true]) => settings[key] is bool ? settings[key] as bool : fallback;
  String settingStr(String key, String fallback) => settings[key] == null ? fallback : '${settings[key]}';
  Units get units => Units(settingStr('units', 'Metric') == 'Imperial');

  /// Night mode (Settings → Accessibility) wins over the system theme.
  ThemeMode get themeMode {
    if (setting('night', false)) return ThemeMode.dark;
    if (setting('nightAuto', false)) {
      final h = DateTime.now().hour;
      if (h >= 21 || h < 6) return ThemeMode.dark;
    }
    return _theme;
  }

  double get textScale => switch (settingStr('textSize', 'Default')) { 'Large' => 1.12, 'Extra large' => 1.25, _ => 1.0 };

  Future<void> boot() async {
    prefs = await SharedPreferences.getInstance();
    token = prefs!.getString(_kToken);
    mode = prefs!.getString(_kMode) ?? 'classic';
    _theme = _parseTheme(prefs!.getString(_kTheme));
    final cached = prefs!.getString(_kCatalog);
    if (cached != null) {
      try {
        catalog = Map<String, dynamic>.from(jsonDecode(cached) as Map);
      } catch (_) {}
    }
    Api.i.token = token;
    Api.i.onUnauthorized = () {
      if (token != null) logout(silent: true);
    };
    await loadCatalog();
    if (token != null) {
      try {
        await refreshMe();
      } on ApiError catch (e) {
        if (e.unauthorized) await logout(silent: true);
      }
    }
    ready = true;
    notifyListeners();
  }

  /// Sports, cuts, allergies … the reference lists every picker uses.
  Future<void> loadCatalog() async {
    try {
      final data = await Api.i.get('catalog/');
      catalog = Map<String, dynamic>.from(data as Map);
      prefs?.setString(_kCatalog, jsonEncode(catalog));
    } catch (_) {
      // keep the cached copy; screens show their own errors if it is empty
    }
  }

  Json sport(String key) => catalog.l('sports').firstWhere((s) => s.s('key') == key, orElse: () => {'key': key, 'l': key, 'mode': 'time', 'env': 'in', 'k': '', 'note': ''});
  String sportLabel(String key) => sport(key).s('l', key);

  Future<void> refreshMe() async {
    final data = await Api.i.get('me/');
    _applyMe(Map<String, dynamic>.from(data as Map));
  }

  void _applyMe(Json user) {
    me = user;
    mode = me.s('mode', mode);
    _theme = _parseTheme(me.s('theme', 'system'));
    prefs?.setString(_kMode, mode);
    prefs?.setString(_kTheme, me.s('theme', 'system'));
    notifyListeners();
  }

  Future<void> signIn(Json response) async {
    token = response.s('token');
    Api.i.token = token;
    await prefs?.setString(_kToken, token!);
    _applyMe(response.m('user'));
  }

  Future<void> logout({bool silent = false}) async {
    if (!silent) {
      try {
        await Api.i.post('auth/logout/');
      } catch (_) {}
    }
    token = null;
    Api.i.token = null;
    me = {};
    await prefs?.remove(_kToken);
    notifyListeners();
  }

  void setMe(Json user) => _applyMe(user);

  Future<Json> updateMe(Json patch) async {
    final data = await Api.i.patch('me/', patch);
    _applyMe(Map<String, dynamic>.from(data as Map));
    return me;
  }

  Future<void> toggleMode() async {
    mode = genz ? 'classic' : 'genz';
    notifyListeners();
    try {
      await updateMe({'mode': mode});
    } catch (_) {}
  }

  /// Optimistic settings write; reverts on failure.
  Future<void> setSetting(String key, Object value) async {
    final before = Map<String, dynamic>.from(settings);
    me = {...me, 'settings': {...before, key: value}};
    notifyListeners();
    try {
      await updateMe({'settings': {key: value}});
    } catch (_) {
      me = {...me, 'settings': before};
      notifyListeners();
      say('Could not save that setting. Check your connection.');
    }
  }

  Future<void> toggleSetting(String key, [bool fallback = true]) => setSetting(key, !setting(key, fallback));

  /// Call after a write so every visible screen reloads.
  void changed() {
    version++;
    notifyListeners();
  }

  void say(String message) {
    if (message.isEmpty) return;
    toast = message;
    final id = ++_toastId;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (id == _toastId) {
        toast = '';
        notifyListeners();
      }
    });
  }

  ThemeMode _parseTheme(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Gen Z only renames the five tabs (as in the client's prototype).
  String tab(String classic) {
    if (!genz) return classic;
    return const {'Home': 'Your W', 'Train': 'Grind', 'Log': 'Fuel', 'Clubs': 'Squads', 'Profile': 'Your Era'}[classic] ?? classic;
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing (for callbacks).
  static AppState read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).notifier!;
}

extension AppX on BuildContext {
  AppState get app => AppScope.read(this);
  AppState get appWatch => AppScope.of(this);
  void say(String m) => AppScope.read(this).say(m);
  Future<T?> push<T>(Widget page) => Navigator.of(this).push<T>(MaterialPageRoute(builder: (_) => page));

  /// Opens above the tab bar (full-screen flows: live session, scan, stories).
  Future<T?> pushRoot<T>(Widget page) =>
      Navigator.of(this, rootNavigator: true).push<T>(MaterialPageRoute(builder: (_) => page, fullscreenDialog: false));
}
