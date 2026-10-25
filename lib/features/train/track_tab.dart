import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../activity/activity_row.dart';
import '../routes.dart';

/// Train → Track: pick any sport, outdoor or indoor, and start.
class TrackTab extends StatelessWidget {
  const TrackTab({super.key});
  static final pick = ValueNotifier<String>('');
  static final env = ValueNotifier<String>('out');

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    if (pick.value.isEmpty) {
      final mine = app.me.strs('sports');
      pick.value = mine.isNotEmpty ? mine.first : 'run';
      env.value = app.sport(pick.value).s('env', 'out');
    }
    return ListenableBuilder(
      listenable: Listenable.merge([pick, env]),
      builder: (context, _) {
        final sports = app.catalog.l('sports').where((s) => s.s('env') == env.value).toList();
        final sp = app.sport(pick.value);
        return Loader<Json>(
          load: () async => Map<String, dynamic>.from(await Api.i.get('train/track/') as Map),
          builder: (context, d, reload) => XPage(padding: const EdgeInsets.fromLTRB(XS.gutter, 16, XS.gutter, 40), children: [
            Text('Every way you move', style: XT.h1(context)),
            gap16,
            XSegment(
              labels: const ['Outdoor', 'Indoor and gym'],
              index: env.value == 'out' ? 0 : 1,
              onPick: (i) {
                env.value = i == 0 ? 'out' : 'in';
                if (app.sport(pick.value).s('env') != env.value) {
                  pick.value = app.catalog.l('sports').firstWhere((s) => s.s('env') == env.value).s('key');
                }
              },
            ),
            gap16,
            XGrid(cols: 3, children: [for (final s in sports) _tile(context, s)]),
            gap16,
            XNote(label: sp.s('l'), text: '${sp.s('note')}${pick.value == 'strength' ? ' Starts today\'s planned session.' : ''}'),
            if (d.b('exhaust')) ...[
              gap12,
              XCard(
                child: Row(children: [
                  const Icon(Icons.dark_mode_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Exhaust Mode is on. Heart-rate cap: Zone 2 (${d.i('cap')} bpm).', style: XT.small(context, color: context.c.ink))),
                ]),
              ),
            ],
            gap16,
            XButton('Start ${sp.s('l').toLowerCase()}', icon: Icons.play_arrow_rounded, onTap: () => Go.startSport(context, pick.value)),
            if (env.value == 'out') ...[gap20, _toggles(context, d.b('private'))],
            gap20,
            Row(children: [const Expanded(child: XLabel('Recent activities')), XLink('All routes', onTap: () => Go.routes(context))]),
            if (d.l('recent').isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Your sessions show up here.', style: XT.small(context))),
            for (final a in d.l('recent')) ActivityRow(a),
          ]),
        );
      },
    );
  }

  Widget _tile(BuildContext context, Json s) {
    final c = context.c;
    final on = pick.value == s.s('key');
    return Semantics(
      selected: on,
      button: true,
      label: s.s('l'),
      child: Press(
        onTap: () => pick.value = s.s('key'),
        child: AnimatedContainer(
          duration: context.anim(XS.fast),
          height: 70,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: on ? c.ink : c.gray,
            borderRadius: BorderRadius.circular(context.genz ? XS.r4 : XS.r2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(s.s('k').toUpperCase(), style: XT.label(context, color: on ? c.onInk.withValues(alpha: .7) : null).copyWith(fontSize: 9.5)),
            Text(s.s('l'), maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.h3(context, color: on ? c.onInk : c.ink).copyWith(fontSize: 14)),
          ]),
        ),
      ),
    );
  }

  Widget _toggles(BuildContext context, bool private) {
    final app = context.appWatch;
    Widget row(String k, String t, String s, bool fallback) => XRow(t, sub: s, trailing: Semantics(
          label: t,
          child: XSwitch(value: app.setting(k, fallback), onChanged: (_) => app.toggleSetting(k, fallback)),
        ));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const XLabel('While tracking'),
      row('autoPause', 'Auto-pause', 'Pauses when you stop at a crossing, resumes when you move', true),
      row('voice', 'Voice updates', 'Distance and pace read out every kilometre', true),
      row('liveLoc', 'Share live location', 'Followers see you are out right now · off by default', false),
      row('demoGps', 'Demo GPS', 'Plays a simulated route instead of your location. For testing indoors.', false),
      gap8,
      Text('Location is used only while a session is running. Who sees the finished route follows your account privacy${private ? ': only approved followers' : ''}.',
          style: XT.small(context)),
    ]);
  }
}
