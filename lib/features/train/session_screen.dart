import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../live/live_screen.dart';
import '../routes.dart';
import 'day_sheet.dart';
import 'plan_tab.dart' show ExerciseRow;

/// A planned day: its exercises (adapted for injuries / Exhaust Mode) and Start.
class SessionScreen extends StatelessWidget {
  final int weekday;
  const SessionScreen({super.key, required this.weekday});

  @override
  Widget build(BuildContext context) {
    return XScreen(
      body: Loader<Json>(
        load: () async => Map<String, dynamic>.from(await Api.i.get('train/day/$weekday/') as Map),
        builder: (context, d, reload) {
          final s = d.m('session');
          final title = '${d.s('day')}${d.b('today') ? ' · today' : ''}';
          if (d.b('rest')) {
            return Column(children: [
              XTopBar('${d.s('day')} · rest day'),
              Expanded(
                child: XPage(children: [
                  Text('Rest day', style: XT.h1(context)),
                  gap8,
                  Text('No training planned. Your streak counts with a 10-minute recovery session and your diet.', style: XT.body(context)),
                  gap20,
                  XButton('Start recovery session', onTap: () => Go.recoverySession(context)),
                  gap8,
                  XButton('Change this day', kind: XBtn.secondary, onTap: () => showDaySheet(context, weekday)),
                ]),
              ),
            ]);
          }
          final ex = s.l('ex');
          final active = ex.where((e) => !e.b('skip')).toList();
          final adapted = ex.any((e) => e.b('adapted') || e.b('skip'));
          return Column(children: [
            XTopBar(title, actions: [XIconBtn(Icons.swap_horiz_rounded, tooltip: 'Swap or change this day', onTap: () => showDaySheet(context, weekday))]),
            Expanded(
              child: XPage(children: [
                XLabel(s.strs('groups').join(' · ')),
                gap8,
                Text(s.s('label'), style: XT.h1(context)),
                gap4,
                Text('${s.i('mins')} min · ${active.length} exercises${d.b('done') ? ' · done' : ''}', style: XT.small(context)),
                gap16,
                if (s.b('exhaust')) ...[
                  XNote(text: 'Exhaust Mode: trimmed to ${active.length} moves, 2 sets each. Stop 3 reps before failure.'),
                  gap12,
                ],
                if (adapted) ...[
                  XNote(text: 'Adapted for your ${d.strs('injury_areas').join(' and ')}. Moves that load it are swapped${ex.any((e) => e.b('skip')) ? ' or skipped' : ''}.'),
                  gap12,
                ],
                for (final e in ex) ExerciseRow(e),
                gap16,
                Text('Rest about 90 seconds between sets, until your breathing settles. Exerlio runs the timer for you.', style: XT.small(context)),
              ]),
            ),
            XDock(row: true, children: [
              XButton('Swap day', icon: Icons.swap_horiz_rounded, kind: XBtn.secondary, onTap: () => showDaySheet(context, weekday)),
              XButton(d.b('done') ? 'Train again' : 'Start session', onTap: () => LiveScreen.start(context,
                  sport: 'strength',
                  title: s.s('label') + (s.b('exhaust') ? ' · Exhaust' : ''),
                  planKey: s.s('key'),
                  weekday: weekday,
                  exercises: active)),
            ]),
          ]);
        },
      ),
    );
  }
}
