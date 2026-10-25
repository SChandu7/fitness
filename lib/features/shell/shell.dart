import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../clubs/clubs_screen.dart';
import '../home/home_screen.dart';
import '../live/live_screen.dart';
import '../live/live_session.dart';
import '../log/log_sheet.dart';
import '../profile/profile_screen.dart';
import '../train/train_screen.dart';

/// Lets any screen switch tabs and sub-sections (e.g. "See all challenges").
class ShellNav {
  static final tab = ValueNotifier<int>(0); // 0 home, 1 train, 2 clubs, 3 profile
  static final homeTab = ValueNotifier<int>(0); // 0 dashboard, 1 social
  static final trainSeg = ValueNotifier<int>(0); // 0 plan, 1 track, 2 challenges
  static final profileTab = ValueNotifier<String>('activity');

  static void go(BuildContext context, int t, {int? home, int? train, String? profile}) {
    if (home != null) homeTab.value = home;
    if (train != null) trainSeg.value = train;
    if (profile != null) profileTab.value = profile;
    tab.value = t;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  bool _logOpen = false;
  final _pages = const [HomeScreen(), TrainScreen(), ClubsScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resume());
  }

  /// After a crash or the phone killing the app: bring back a running session
  /// and upload any finished workout that could not be sent.
  Future<void> _resume() async {
    final pending = await PendingActivity.flush();
    if (!mounted) return;
    if (pending != null) {
      context.say('Your last workout was saved.');
      context.app.changed();
    }
    if (LiveSession.active.value == null) {
      final s = await LiveSession.restore();
      if (s != null && mounted) {
        context.say('${s.title} is still open. Resume or finish it.');
        context.pushRoot(const LiveScreen());
      }
    }
  }

  Future<void> _openLog() async {
    setState(() => _logOpen = true);
    await showLogSheet(context);
    if (mounted) setState(() => _logOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final c = context.c;
    return ValueListenableBuilder<int>(
      valueListenable: ShellNav.tab,
      builder: (context, tab, _) => PopScope(
        canPop: tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) ShellNav.tab.value = 0;
        },
        child: Scaffold(
          backgroundColor: c.bg,
          body: IndexedStack(index: tab, children: _pages),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(children: [
                  _item(0, tab, Icons.home_outlined, Icons.home_rounded, app.tab('Home')),
                  _item(1, tab, Icons.fitness_center_outlined, Icons.fitness_center_rounded, app.tab('Train')),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Log a workout, meal, water, weight or activity',
                      child: Press(
                        onTap: _openLog,
                        haptic: true,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          AnimatedContainer(
                            duration: context.anim(XS.fast),
                            width: 40,
                            height: 32,
                            decoration: BoxDecoration(color: _logOpen ? c.orange : c.ink, borderRadius: BorderRadius.circular(12)),
                            child: AnimatedRotation(
                              turns: _logOpen ? .125 : 0,
                              duration: context.anim(XS.base),
                              child: Icon(Icons.add_rounded, size: 22, color: _logOpen ? const Color(0xFF000000) : c.onInk),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(app.tab('Log'), style: XT.label(context, color: c.ink).copyWith(fontSize: 10, letterSpacing: .2)),
                        ]),
                      ),
                    ),
                  ),
                  _item(2, tab, Icons.groups_outlined, Icons.groups_rounded, app.tab('Clubs')),
                  _item(3, tab, Icons.person_outline_rounded, Icons.person_rounded, app.tab('Profile')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int i, int tab, IconData icon, IconData active, String label) {
    final c = context.c;
    final on = i == tab;
    return Expanded(
      child: Semantics(
        selected: on,
        button: true,
        label: label,
        child: Press(
          onTap: () {
            if (on) {
              Navigator.of(context).popUntil((r) => r.isFirst);
            }
            ShellNav.tab.value = i;
          },
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedContainer(
              duration: context.anim(XS.fast),
              width: 4,
              height: 4,
              decoration: BoxDecoration(color: on ? c.orange : Colors.transparent, shape: BoxShape.circle),
            ),
            const SizedBox(height: 4),
            Icon(on ? active : icon, size: 23, color: on ? c.ink : c.navIdle),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: XT.label(context, color: on ? c.ink : c.navIdle).copyWith(fontSize: 10, letterSpacing: .2)),
          ]),
        ),
      ),
    );
  }
}
