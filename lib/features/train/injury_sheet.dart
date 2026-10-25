import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/ui.dart';

/// Add a strain or sprain. Every session that loads it adapts until marked healed.
Future<void> showInjurySheet(BuildContext context) {
  final app = context.app;
  final areas = app.catalog.l('areas');
  final levels = app.catalog.l('injury_levels');
  var area = 'knee', side = 'Left', level = 'mild';
  final note = TextEditingController();
  return showXSheet(
    context,
    (ctx) => StatefulBuilder(builder: (ctx, set) {
      final sided = areas.firstWhere((a) => a.s('key') == area, orElse: () => {'sided': true}).b('sided', true);
      return XSheetBody(children: [
        const XSheetHead('Strain or sprain', sub: 'Exerlio adapts every session that loads it until you mark it healed.'),
        const XLabel('Where'),
        gap8,
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final a in areas) XChip(a.s('label'), on: a.s('key') == area, onTap: () => set(() => area = a.s('key'))),
        ]),
        if (sided) ...[
          gap16,
          const XLabel('Side'),
          gap8,
          XSegment(labels: const ['Left', 'Right', 'Both'], index: const ['Left', 'Right', 'Both'].indexOf(side), onPick: (i) => set(() => side = const ['Left', 'Right', 'Both'][i])),
        ],
        gap16,
        const XLabel('How bad is it'),
        gap8,
        for (final l in levels) ...[
          XChoice(title: '${l.s('label')} · ${l.s('detail')}', sub: l.s('note'), on: l.s('key') == level, onTap: () => set(() => level = l.s('key'))),
          gap8,
        ],
        XField(controller: note, hint: 'Note, e.g. tweaked it on lunges'),
        gap16,
        XButton('Adapt my workouts', onTap: () async {
          Navigator.pop(ctx);
          final r = await attempt(context, () => Api.i.post('injuries/', {'area': area, 'side': sided ? side : 'na', 'level': level, 'note': note.text.trim()}));
          if (r != null && context.mounted) {
            context.say('${(r as Map)['message']}');
            context.app.changed();
          }
        }),
      ]);
    }),
  );
}
