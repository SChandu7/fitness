import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/charts.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';
import '../shell/shell.dart';

/// After a session: what you did, where you struggled, what to eat next.
class SummaryScreen extends StatelessWidget {
  final Json result;
  const SummaryScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = result.m('activity');
    final pts = RouteMap.parse(a['points']);
    final hr = [for (final v in (a['hr'] as List? ?? const [])) v as num];
    final struggles = a.l('struggles');
    final prs = result.l('prs');
    final finished = result.strs('finished');
    return XScreen(
      body: Column(children: [
        XTopBar('Workout saved', back: false, actions: [XIconBtn(Icons.close_rounded, tooltip: 'Close', onTap: () => ShellNav.go(context, 0))]),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 4, XS.gutter, 24), children: [
            XKicker('${a.s('title')} · ${a.s('when')}'),
            gap8,
            Text(a.s('time'), style: XT.hero(context).copyWith(fontSize: 72)),
            gap16,
            XGrid(cols: 2, children: [for (final s in a.l('stats')) XStatBox(s.s('label'), s.s('value'))]),
            if (pts.length > 2) ...[
              gap16,
              ClipRRect(borderRadius: BorderRadius.circular(XS.r3), child: RouteMap(points: pts, height: 200, distanceKm: a.d('distance_km'))),
            ],
            gap12,
            XButton(pts.length > 2 ? 'Route map, splits and details' : 'Session details',
                icon: pts.length > 2 ? Icons.place_outlined : Icons.monitor_heart_outlined, kind: XBtn.secondary,
                onTap: () => Go.activity(context, a.i('id'))),
            if (finished.isNotEmpty) ...[
              gap16,
              XCard(
                dark: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  XKicker('Challenge complete', color: c.onInk.withValues(alpha: .7)),
                  gap8,
                  for (final f in finished) Text(f, style: XT.h3(context, color: c.onInk)),
                  gap4,
                  Text('Bonus streak days added. Your streak is now ${result.i('streak')} days.', style: XT.small(context, color: c.onInk.withValues(alpha: .7))),
                ]),
              ),
            ],
            if (prs.isNotEmpty) ...[
              gap16,
              for (final p in prs)
                XCard(
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: c.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.emoji_events_outlined, size: 20, color: Color(0xFF000000)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const XLabel('New personal record'),
                        gap4,
                        Text('${p.s('name')} · ${p.s('value')}', style: XT.h3(context)),
                        Text(p.s('delta'), style: XT.small(context)),
                      ]),
                    ),
                  ]),
                ),
            ],
            if (hr.length > 3) ...[
              gap16,
              XCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const XLabel('Heart rate · from your watch'),
                  gap12,
                  HrChart(hr: hr, maxHr: a.i('max_hr', 190), height: 120),
                  gap12,
                  ZoneRow([for (final z in (a['zones'] as List? ?? const [])) (z as num).toInt()]),
                ]),
              ),
              gap16,
              if (struggles.isEmpty)
                const XNote(text: 'No spikes above 92% of max. Well paced.')
              else ...[
                const XLabel('Where you struggled'),
                gap8,
                for (final s in struggles)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s.s('label')} · min ${s.i('min')} · ${s.i('hr')} bpm', style: XT.h3(context).copyWith(fontSize: 15)),
                      gap4,
                      Text(s.s('advice'), style: XT.small(context)),
                    ]),
                  ),
              ],
            ],
            gap16,
            XCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                XKicker('Next 45 minutes', color: c.ink),
                gap8,
                Text(result.s('next'), style: XT.small(context, color: c.ink)),
                gap12,
                XButton('Log recovery meal', icon: Icons.document_scanner_outlined, small: true, expand: false, kind: XBtn.secondary,
                    onTap: () => Go.scan(context, slot: 'Post-workout')),
              ]),
            ),
          ]),
        ),
      ]),
      dock: XDock(row: true, children: [
        XButton('Save only', kind: XBtn.secondary, onTap: () => ShellNav.go(context, 0)),
        XButton('Share to feed', onTap: () async {
          final r = await attempt(context, () => Api.i.post('posts/', {'activity_id': a.i('id'), 'body': ''}));
          if (r != null && context.mounted) {
            context.say('Shared to your feed');
            context.app.changed();
            ShellNav.go(context, 0, home: 1);
          }
        }),
      ]),
    );
  }
}
