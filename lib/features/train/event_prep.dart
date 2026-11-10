import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Train → Plan: training towards a race or event. Empty state invites one; otherwise a countdown,
/// the phase, today's event session and the next seven days.
class EventPrepCard extends StatelessWidget {
  final Json? event;
  const EventPrepCard(this.event, {super.key});

  @override
  Widget build(BuildContext context) {
    final e = event;
    if (e == null || e.isEmpty) {
      return XCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const XKicker('Event preparation'),
          gap8,
          Text('Got an event coming up?', style: XT.h2(context)),
          gap4,
          Text('Build training around your race date, the event, your level and your target.', style: XT.small(context)),
          gap12,
          XButton('Prepare for an event', icon: Icons.event_outlined, onTap: () => showEventForm(context, null)),
        ]),
      );
    }
    final c = context.c;
    final on = c.onInk, dim = c.onInk.withValues(alpha: .72), hot = c.orange;
    final today = e.m('today');
    final past = e.b('past');
    return XCard(
      dark: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: XKicker('Event · ${e.s('name')}', color: on)),
          Press(
            onTap: () => showEventForm(context, e),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Text('Edit', style: XT.small(context, color: on).copyWith(fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
            ),
          ),
        ]),
        gap12,
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(past ? 'Done' : '${e.i('days_left')}', style: XT.metric(context, 40, color: on)),
              Text(past ? 'How did it go?' : (e.i('days_left') == 1 ? 'day to go' : 'days to go'), style: XT.small(context, color: dim)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(e.s('phase').toUpperCase(), style: XT.label(context, color: hot)),
            const SizedBox(height: 4),
            Text(e.s('date_label'), style: XT.small(context, color: on)),
          ]),
        ]),
        if (!past && today.isNotEmpty) ...[
          gap16,
          Text("TODAY'S EVENT SESSION", style: XT.label(context, color: hot)),
          gap4,
          Text(today.s('title'), style: XT.h3(context, color: on)),
          const SizedBox(height: 2),
          Text(today.s('detail'), style: XT.small(context, color: dim)),
        ],
        gap8,
        Text([
          if (e.s('target').isNotEmpty) 'Target: ${e.s('target')}' else 'Goal: arrive healthy and ready',
          '${e.s('level_label')} · ${e.i('days_per_week')} training days a week',
        ].join('\n'), style: XT.small(context, color: dim)),
        gap12,
        Row(children: [
          if (!past) Expanded(child: XButton('Next 7 days', small: true, kind: XBtn.accent, onTap: () => _schedule(context))),
          if (!past) const SizedBox(width: 8),
          Expanded(
            child: XButton(past ? 'Plan another event' : 'Change event', small: true, kind: XBtn.secondary,
                onTap: () => showEventForm(context, past ? null : e)),
          ),
        ]),
        gap8,
        Text('No plan can promise a result. This one aims to get you to the start line healthy and prepared.',
            style: XT.small(context, color: c.onInk.withValues(alpha: .6)).copyWith(fontSize: 11)),
      ]),
    );
  }

  Future<void> _schedule(BuildContext context) async {
    Json d;
    try {
      d = Map<String, dynamic>.from(await Api.i.get('train/event/') as Map).m('event');
    } on ApiError catch (e) {
      if (context.mounted) context.say(e.message);
      return;
    }
    if (!context.mounted) return;
    final c = context.c;
    await showXSheet(context, (ctx) => XSheetBody(children: [
          XSheetHead('Next 7 days', sub: '${d.s('name')} · ${d.s('phase')}'),
          for (final s in d.l('schedule'))
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 64,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.s('day'), style: XT.h3(ctx).copyWith(fontSize: 15)),
                    Text(s.i('to_go') == 0 ? 'Event day' : '${s.i('to_go')} to go', style: XT.small(ctx).copyWith(fontSize: 12)),
                  ]),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.s('title'), style: XT.h3(ctx).copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(s.s('detail'), style: XT.small(ctx)),
                  ]),
                ),
              ]),
            ),
          gap16,
        ]));
  }
}

/// Create or edit the event. Saving replaces the current one; there is one event at a time.
Future<void> showEventForm(BuildContext context, Json? e) async {
  final app = context.app;
  final name = TextEditingController(text: e?.s('name') ?? '');
  final target = TextEditingController(text: e?.s('target') ?? '');
  var kind = e?.s('kind') ?? 'custom';
  var level = e?.s('level') ?? app.me.s('experience', 'intermediate');
  var days = e?.i('days_per_week', 4) ?? 4;
  DateTime? date = e == null ? null : DateTime.tryParse(e.s('date'));
  var err = '';
  final saved = await showXSheet<bool>(context, (ctx) => StatefulBuilder(builder: (ctx, set) {
        Future<void> save() async {
          if (name.text.trim().isEmpty) return set(() => err = 'Name your event.');
          if (date == null) return set(() => err = 'Pick the event date.');
          final d = date!;
          final r = await attempt(ctx, () => Api.i.post('train/event/', {
                'name': name.text.trim(),
                'kind': kind,
                'date': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                'level': level,
                'target': target.text.trim(),
                'days_per_week': days,
              }));
          if (r != null && ctx.mounted) {
            ctx.say('${(r as Map)['message']}');
            Navigator.pop(ctx, true);
          }
        }

        final now = DateTime.now();
        return XSheetBody(children: [
          XSheetHead(e == null ? 'Prepare for an event' : 'Your event', sub: 'Training adapts to the event and the time left.'),
          const XLabel('Event name'),
          gap8,
          XField(controller: name, hint: 'e.g. HYROX Hyderabad'),
          gap16,
          const XLabel('Event type'),
          gap8,
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in app.catalog.l('event_kinds')) XChip(k.s('label'), on: kind == k.s('key'), onTap: () => set(() => kind = k.s('key'))),
          ]),
          gap16,
          const XLabel('Event date'),
          gap8,
          XRow(date == null ? 'Pick a date' : '${date!.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date!.month - 1]} ${date!.year}',
              leading: const Icon(Icons.calendar_today_outlined, size: 20),
              chevron: true,
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: date ?? now.add(const Duration(days: 28)),
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: now.add(const Duration(days: 730)),
                );
                if (picked != null) set(() => date = picked);
              }),
          gap16,
          const XLabel('Your current level'),
          gap8,
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final l in app.catalog.l('levels')) XChip(l.s('label'), on: level == l.s('key'), onTap: () => set(() => level = l.s('key'))),
          ]),
          gap16,
          const XLabel('Your target · optional'),
          gap8,
          XField(controller: target, hint: 'e.g. finish under 1:20'),
          gap16,
          const XLabel('Training days a week'),
          gap8,
          XSegment(ink: true, labels: const ['2', '3', '4', '5', '6', '7'], index: (days - 2).clamp(0, 5), onPick: (i) => set(() => days = i + 2)),
          if (err.isNotEmpty) ...[gap12, Text(err, style: XT.small(ctx, color: ctx.c.red))],
          gap20,
          XButton(e == null ? 'Build my event plan' : 'Save', onTap: save),
          if (e != null) ...[
            gap8,
            XButton('Remove event', kind: XBtn.secondary, onTap: () async {
              final r = await attempt(ctx, () => Api.i.delete('train/event/'));
              if (r != null && ctx.mounted) {
                ctx.say('${(r as Map)['message']}');
                Navigator.pop(ctx, true);
              }
            }),
          ],
          gap8,
          Text('Close to the date, the plan focuses on readiness and recovery rather than last-minute fitness.', style: XT.small(ctx)),
          gap16,
        ]);
      }));
  name.dispose();
  target.dispose();
  if (saved == true && context.mounted) context.app.changed();
}
