import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'core/ui.dart';
import 'features/auth/welcome_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState();
  runApp(AppScope(state: state, child: const ExerlioApp()));
  await state.boot();
}

class ExerlioApp extends StatelessWidget {
  const ExerlioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    return MaterialApp(
      title: 'Exerlio',
      debugShowCheckedModeBanner: false,
      themeMode: app.themeMode,
      theme: buildTheme(XC.light, Brightness.light),
      darkTheme: buildTheme(XC.dark, Brightness.dark),
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final c = dark ? XC.dark : XC.light;
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * app.textScale)),
          child: XTheme(
            c: c,
            genz: app.genz,
            reduceMotion: app.setting('reduceMotion', false),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
              child: Stack(children: [child!, const _ToastLayer()]),
            ),
          ),
        );
      },
      home: const _Gate(),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();
  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    if (!app.ready) return const _Splash();
    if (!app.loggedIn) return const WelcomeScreen();
    if (!app.onboarded) return const OnboardingScreen();
    return const Shell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.c.bg,
        body: const Center(child: Wordmark(size: 18)),
      );
}

class _ToastLayer extends StatelessWidget {
  const _ToastLayer();
  @override
  Widget build(BuildContext context) {
    final msg = context.appWatch.toast;
    final c = context.c;
    return Positioned(
      left: 16,
      right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 92,
      child: IgnorePointer(
        child: AnimatedSwitcher(
          duration: context.anim(XS.base),
          child: msg.isEmpty
              ? const SizedBox.shrink()
              : Material(
                  key: ValueKey(msg),
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(XS.r2)),
                    child: Text(msg, style: XT.body(context, color: c.onInk).copyWith(fontSize: 14)),
                  ),
                ),
        ),
      ),
    );
  }
}
