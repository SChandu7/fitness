import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/ui.dart';

/// Three taps → a recovery score when no watch is connected.
Future<void> showCheckinSheet(BuildContext context) {
  double sleep = 7;
  int sore = 2, energy = 4;
  return showXSheet(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => XSheetBody(children: [
        const XSheetHead('How are you today?', sub: 'Three quick taps give you a recovery score.'),
        const XLabel('Sleep last night'),
        gap8,
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final h in [5.0, 6.0, 7.0, 8.0, 9.0])
            XChip(h == 5 ? 'Under 6 h' : h == 9 ? '9 h +' : '${h.round()} h', on: sleep == h, onTap: () => set(() => sleep = h)),
        ]),
        gap16,
        const XLabel('How sore are you'),
        gap8,
        XSegment(labels: const ['None', 'A bit', 'Some', 'Sore', 'Very'], index: sore - 1, onPick: (i) => set(() => sore = i + 1)),
        gap16,
        const XLabel('Energy'),
        gap8,
        XSegment(labels: const ['Low', 'Meh', 'OK', 'Good', 'High'], index: energy - 1, onPick: (i) => set(() => energy = i + 1)),
        gap20,
        XButton('See my score', onTap: () async {
          Navigator.pop(ctx);
          final r = await attempt(context, () => Api.i.post('checkin/', {'sleep_hours': sleep, 'soreness': sore, 'energy': energy}));
          if (r != null && context.mounted) {
            context.say('Recovery ${(r as Map)['score']}. ${r['label']}.');
            context.app.changed();
          }
        }),
      ]),
    ),
  );
}
