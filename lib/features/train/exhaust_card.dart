import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Exhaust Mode: lighter session, protein-only goal at 80 %, streak still counts.
/// [full] adds the "Ask me after work" controls (Train → Plan).
class ExhaustCard extends StatelessWidget {
  final bool full;
  const ExhaustCard({super.key, this.full = false});

  Future<void> _toggle(BuildContext context, bool on) async {
    final r = await attempt(context, () => Api.i.post('exhaust/', {'on': on}));
    if (r != null && context.mounted) {
      context.say('${(r as Map)['message']}');
      await context.app.refreshMe();
      if (context.mounted) context.app.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appWatch;
    final me = app.me;
    final on = me.b('exhaust');
    final cap = (me.m('targets').i('max_hr', 190) * .7).round();
    final c = context.c;
    final rows = [
      ['Workout', '3 moves for big muscle groups, 2 for small ones, 2 sets each, heart rate capped at Zone 2 ($cap bpm).'],
      ['Food', 'One-tap meals and a protein-only goal at 80%. No counting every gram.'],
      ['Streak', 'Still counts. Showing up on a hard day is what consistency is.'],
    ];
    final hour = me.i('work_end_hour', 19);
    return XCard(
      muted: on,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.dark_mode_outlined, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Exhaust Mode', style: XT.h3(context)),
              Text('For drained days and late finishes at work', style: XT.small(context)),
            ]),
          ),
          Semantics(label: 'Exhaust Mode', child: XSwitch(value: on, onChanged: (v) => _toggle(context, v))),
        ]),
        gap12,
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 64, child: Text(r[0], style: XT.small(context, color: c.ink).copyWith(fontWeight: FontWeight.w600))),
              Expanded(child: Text(r[1], style: XT.small(context, color: c.ink))),
            ]),
          ),
        if (full) ...[
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ask me after work', style: XT.h3(context).copyWith(fontSize: 15)),
                  Text('Work ends ${hourLabel(hour)}', style: XT.small(context)),
                ]),
              ),
              XIconBtn(Icons.remove_rounded, tooltip: 'Earlier', onTap: hour <= 14 ? () {} : () => app.updateMe({'work_end_hour': hour - 1})),
              XIconBtn(Icons.add_rounded, tooltip: 'Later', onTap: hour >= 23 ? () {} : () => app.updateMe({'work_end_hour': hour + 1})),
              Semantics(
                label: 'Suggest Exhaust Mode after work',
                child: XSwitch(
                  value: me.b('exhaust_auto', true),
                  onChanged: (v) async {
                    await attempt(context, () => app.updateMe({'exhaust_auto': v}));
                    if (context.mounted) context.say(v ? 'Exerlio will ask after ${hourLabel(hour)}' : 'After-work suggestion off');
                  },
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
