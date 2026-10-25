import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../shell/shell.dart';

/// Event fuel plan: before, race day, after. Built from your weight and start time.
class FuelScreen extends StatefulWidget {
  const FuelScreen({super.key});
  @override
  State<FuelScreen> createState() => _FuelScreenState();
}

class _FuelScreenState extends State<FuelScreen> {
  String _phase = 'pre';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Loader<Json>(
        key: ValueKey(_phase),
        load: () async => Map<String, dynamic>.from(await Api.i.get('fuel/?phase=$_phase') as Map),
        builder: (context, d, reload) {
          final e = d.m('event');
          if (e.isEmpty) {
            return Column(children: [
              const XTopBar('Fuel plan'),
              Expanded(
                child: XEmpty(
                  icon: Icons.event_outlined,
                  title: 'No race coming up',
                  body: 'Tap "I am going" on a race, long run or long ride in a club, and your fuel plan shows up here.',
                  action: 'Browse clubs',
                  onAction: () => ShellNav.go(context, 2),
                ),
              ),
            ]);
          }
          final rows = e.l('rows');
          return Column(children: [
            const XTopBar('Fuel plan'),
            Expanded(
              child: XPage(children: [
                XKicker('${e.s('title')} · ${e.s('when')}'),
                gap8,
                Text('Eat for the race, not just on the day', style: XT.h1(context)),
                gap4,
                Text('Built from your weight (${e.d('weight').toStringAsFixed(0)} kg) and your start time.', style: XT.small(context)),
                gap16,
                XSegment(labels: const ['Before', 'Race day', 'After'], index: const ['pre', 'day', 'post'].indexOf(_phase),
                    onPick: (i) => setState(() => _phase = const ['pre', 'day', 'post'][i])),
                gap8,
                for (var i = 0; i < rows.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(border: i < rows.length - 1 ? Border(bottom: BorderSide(color: c.line)) : null),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 74, child: Text(rows[i].s('time'), style: XT.small(context, color: c.ink).copyWith(fontWeight: FontWeight.w600))),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(rows[i].s('title'), style: XT.h3(context).copyWith(fontSize: 15)),
                          gap4,
                          Text(rows[i].s('text'), style: XT.small(context)),
                        ]),
                      ),
                    ]),
                  ),
                gap16,
                const XNote(label: 'Why plan meals around an event',
                    text: 'What you eat two days out decides how you feel in the last kilometre. What you eat in the first hour after decides how fast you are back to training.'),
              ]),
            ),
            XDock(children: [
              XButton(e.b('added') ? 'Added to your days' : 'Add plan to my days', icon: e.b('added') ? Icons.check_rounded : null,
                  kind: e.b('added') ? XBtn.secondary : XBtn.primary, onTap: () async {
                final r = await attempt(context, () => Api.i.post('fuel/${e.i('event_id')}/add/'));
                if (r != null && context.mounted) {
                  context.say('${(r as Map)['message']}');
                  context.app.changed();
                }
              }),
            ]),
          ]);
        },
      ),
    );
  }
}
