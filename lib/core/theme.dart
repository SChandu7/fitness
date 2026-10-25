import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Exerlio Design System 2.0
/// WHITE = SPACE · BLACK = STRUCTURE · ORANGE = ACTION (10% or less)
class XC {
  final Color bg, surface, ink, onInk, gray, gray2, line, muted, navIdle, faint, orange, success, red, redBg, green;
  const XC({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.onInk,
    required this.gray,
    required this.gray2,
    required this.line,
    required this.muted,
    required this.navIdle,
    required this.faint,
    required this.orange,
    required this.success,
    required this.red,
    required this.redBg,
    required this.green,
  });

  static const light = XC(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF000000),
    onInk: Color(0xFFFFFFFF),
    gray: Color(0xFFF2F2F2),
    gray2: Color(0xFFD9D9D9),
    line: Color(0xFFE6E6E6),
    muted: Color(0xFF6B6B6B),
    navIdle: Color(0xFF767676),
    faint: Color(0xFF9A9A9A),
    orange: Color(0xFFFF6B00),
    success: Color(0xFF000000),
    red: Color(0xFFD92D20),
    redBg: Color(0xFFFFF5F4),
    green: Color(0xFF12A150),
  );

  /// Inverse: black canvas, white structure, same orange.
  static const dark = XC(
    bg: Color(0xFF000000),
    surface: Color(0xFF0D0D0D),
    ink: Color(0xFFFFFFFF),
    onInk: Color(0xFF000000),
    gray: Color(0xFF1A1A1A),
    gray2: Color(0xFF333333),
    line: Color(0xFF262626),
    muted: Color(0xFFA3A3A3),
    navIdle: Color(0xFF8A8A8A),
    faint: Color(0xFF6B6B6B),
    orange: Color(0xFFFF6B00),
    success: Color(0xFFFFFFFF),
    red: Color(0xFFFF5A4E),
    redBg: Color(0xFF2A1210),
    green: Color(0xFF3CCB7F),
  );
}

/// Spacing scale s1–s8 and radii from the brand guide.
class XS {
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 24.0, s6 = 32.0, s7 = 48.0, s8 = 64.0;
  static const gutter = 24.0;
  static const r1 = 8.0, rSm = 10.0, r2 = 12.0, r3 = 16.0, r4 = 20.0;
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 300);
  static const ease = Cubic(.2, .7, .2, 1);
}

/// Everything below the root reads colours + mode from here.
class XTheme extends InheritedWidget {
  final XC c;
  final bool genz;
  final bool reduceMotion;
  const XTheme({super.key, required this.c, required this.genz, required this.reduceMotion, required super.child});

  static XTheme of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<XTheme>()!;

  @override
  bool updateShouldNotify(XTheme old) => old.c != c || old.genz != genz || old.reduceMotion != reduceMotion;
}

extension XThemeX on BuildContext {
  XC get c => XTheme.of(this).c;
  bool get genz => XTheme.of(this).genz;
  Duration anim(Duration d) => XTheme.of(this).reduceMotion ? Duration.zero : d;
}

/// Inter type scale. Numbers always use tabular figures.
class XT {
  static const _tab = [FontFeature.tabularFigures(), FontFeature('cv11'), FontFeature('ss01')];

  static TextStyle _inter(double size, FontWeight w, double height, double tracking, Color color) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: w,
        height: height,
        letterSpacing: size * tracking,
        color: color,
        fontFeatures: _tab,
      );

  static TextStyle hero(BuildContext ctx, {Color? color}) =>
      _inter(88, FontWeight.w400, .9, -.06, color ?? ctx.c.ink);
  static TextStyle big(BuildContext ctx, {Color? color, double size = 56}) =>
      _inter(size, FontWeight.w500, .95, -.05, color ?? ctx.c.ink);
  static TextStyle display(BuildContext ctx, {Color? color}) =>
      _inter(36, ctx.genz ? FontWeight.w600 : FontWeight.w500, 1.04, ctx.genz ? -.055 : -.04, color ?? ctx.c.ink);
  static TextStyle h1(BuildContext ctx, {Color? color}) =>
      _inter(28, ctx.genz ? FontWeight.w600 : FontWeight.w500, 1.1, ctx.genz ? -.055 : -.03, color ?? ctx.c.ink);
  static TextStyle h2(BuildContext ctx, {Color? color}) =>
      _inter(21, ctx.genz ? FontWeight.w600 : FontWeight.w500, 1.2, ctx.genz ? -.04 : -.02, color ?? ctx.c.ink);
  static TextStyle h3(BuildContext ctx, {Color? color}) =>
      _inter(16, FontWeight.w500, 1.3, -.01, color ?? ctx.c.ink);
  static TextStyle body(BuildContext ctx, {Color? color}) =>
      _inter(15, FontWeight.w400, 1.5, 0, color ?? ctx.c.ink);
  static TextStyle small(BuildContext ctx, {Color? color}) =>
      _inter(13, FontWeight.w400, 1.45, 0, color ?? ctx.c.muted);
  static TextStyle label(BuildContext ctx, {Color? color}) =>
      _inter(11, FontWeight.w500, 1, ctx.genz ? .12 : .09, color ?? ctx.c.muted);
  static TextStyle button(BuildContext ctx, {Color? color}) =>
      _inter(15, ctx.genz ? FontWeight.w600 : FontWeight.w500, 1, 0, color ?? ctx.c.onInk);
  static TextStyle metric(BuildContext ctx, double size, {Color? color}) =>
      _inter(size, FontWeight.w500, 1, -.03, color ?? ctx.c.ink);
}

ThemeData buildTheme(XC c, Brightness b) {
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: c.orange, brightness: b, surface: c.bg, primary: c.ink),
    fontFamily: 'Inter',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: c.line,
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.orange, selectionHandleColor: c.orange),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
