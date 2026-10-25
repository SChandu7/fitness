import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../challenges/challenges_tab.dart';
import '../live/live_screen.dart';
import '../live/live_session.dart';
import '../shell/shell.dart';
import 'plan_tab.dart';
import 'track_tab.dart';

/// Train: Plan · Track · Challenges.
class TrainScreen extends StatelessWidget {
  const TrainScreen({super.key});

  void _allSports(BuildContext context) {
    final app = context.app;
    showXSheet(
      context,
      (ctx) => XSheetBody(children: [
        const XSheetHead('All sports'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in app.catalog.l('sports'))
            XChip(s.s('l'), on: TrackTab.pick.value == s.s('key'), onTap: () {
              TrackTab.pick.value = s.s('key');
              TrackTab.env.value = s.s('env');
              ShellNav.trainSeg.value = 1;
              Navigator.pop(ctx);
            }),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(XS.gutter, 4, 8, 0),
          child: SizedBox(
            height: 52,
            child: Row(children: [
              Expanded(child: Text(context.appWatch.tab('Train'), style: XT.h3(context).copyWith(fontSize: 17))),
              XIconBtn(Icons.search_rounded, tooltip: 'Search sports', onTap: () => _allSports(context)),
            ]),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: ShellNav.trainSeg,
          builder: (context, seg, _) => Padding(
            padding: const EdgeInsets.fromLTRB(XS.gutter, 0, XS.gutter, 4),
            child: XSegment(labels: const ['Plan', 'Track', 'Challenges'], index: seg, onPick: (i) => ShellNav.trainSeg.value = i),
          ),
        ),
        ValueListenableBuilder<LiveSession?>(
          valueListenable: LiveSession.active,
          builder: (context, s, _) => s == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(XS.gutter, 10, XS.gutter, 0),
                  child: ListenableBuilder(
                    listenable: s,
                    builder: (context, _) => XCard(
                      dark: true,
                      onTap: () => context.push(const LiveScreen()),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(children: [
                        const XDot(),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${s.title} in progress · ${fmtT(s.elapsed)}', style: XT.h3(context, color: c.onInk).copyWith(fontSize: 15))),
                        Icon(Icons.chevron_right_rounded, color: c.onInk),
                      ]),
                    ),
                  ),
                ),
        ),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: ShellNav.trainSeg,
            builder: (context, seg, _) => IndexedStack(index: seg, children: const [PlanTab(), TrackTab(), ChallengesTab()]),
          ),
        ),
      ]),
    );
  }
}
