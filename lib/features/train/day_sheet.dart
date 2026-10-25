import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// Tap a day: swap it with another day, change its cut, or (today) take the lighter suggestion.
Future<void> showDaySheet(BuildContext context, int i) async {
  Json d;
  try {
    d = Map<String, dynamic>.from(await Api.i.get('train/day/$i/') as Map);
  } on ApiError catch (e) {
    if (context.mounted) context.say(e.message);
    return;
  }
  if (!context.mounted) return;

  Future<void> post(BuildContext ctx, Json body) async {
    Navigator.pop(ctx);
    final r = await attempt(context, () => Api.i.post('schedule/', body));
    if (r != null && context.mounted) {
      context.say('${(r as Map)['message']}');
      context.app.changed();
    }
  }

  final c = context.c;
  final sug = d.m('suggestion');
  return showXSheet(
    context,
    (ctx) => XSheetBody(children: [
      XSheetHead('${d.s('day')} · ${d.s('label')}', sub: d.s('sub')),
      if (sug.isNotEmpty) ...[
        XNote(
          label: 'Too tired for ${d.s('short').toLowerCase()} today?',
          dot: true,
          text: 'Swap with ${sug.s('day')} (${sug.s('label').toLowerCase()}). Lighter today, and ${d.s('label').toLowerCase()} still gets done this week.',
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            XButton('Swap with ${sug.s('day')}', small: true, expand: false, onTap: () => post(ctx, {'action': 'swap', 'i': i, 'j': sug.i('j')})),
            XButton('Exhaust Mode instead', small: true, expand: false, kind: XBtn.secondary, onTap: () async {
              Navigator.pop(ctx);
              final r = await attempt(context, () => Api.i.post('exhaust/', {'on': true}));
              if (r != null && context.mounted) {
                context.say('${(r as Map)['message']}');
                await context.app.refreshMe();
                if (context.mounted) context.app.changed();
              }
            }),
          ]),
        ),
        gap16,
      ],
      if (!d.b('rest')) ...[
        XButton("See ${d.s('day')}'s exercises", kind: XBtn.secondary, onTap: () {
          Navigator.pop(ctx);
          Go.session(context, i);
        }),
        gap16,
      ],
      const XLabel('Swap with another day'),
      for (final o in d.l('days'))
        Press(
          onTap: () => post(ctx, {'action': 'swap', 'i': i, 'j': o.i('j')}),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Row(children: [
              SizedBox(width: 44, child: Text(o.s('day'), style: XT.small(context, color: c.ink).copyWith(fontWeight: FontWeight.w600))),
              Expanded(
                child: Text('${o.s('label')}${o.b('done') ? ' · done' : ''}',
                    style: XT.body(context, color: o.b('rest') ? c.muted : c.ink)),
              ),
              Icon(Icons.swap_vert_rounded, size: 18, color: c.muted),
            ]),
          ),
        ),
      gap20,
      XLabel('Change ${d.s('day')} to'),
      gap8,
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final cut in d.l('cuts'))
          XChip(cut.s('label'), on: cut.s('key') == d.s('key'), onTap: () => post(ctx, {'action': 'set', 'i': i, 'key': cut.s('key')})),
      ]),
    ]),
  );
}
