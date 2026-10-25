import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../create/create_sheet.dart';
import '../routes.dart';

/// The Log (+) tab: a 3 × 2 grid. The most useful next thing is highlighted.
Future<void> showLogSheet(BuildContext context) async {
  Json? d;
  try {
    d = Map<String, dynamic>.from(await Api.i.get('home/') as Map);
  } catch (_) {}
  if (!context.mounted) return;
  final parts = d?.m('streak').l('parts') ?? const <Json>[];
  bool ok(String k) => parts.firstWhere((p) => p.s('key') == k, orElse: () => {'ok': true}).b('ok');
  final plan = d?.m('plan').l('items') ?? const <Json>[];
  final wo = plan.firstWhere((p) => p.s('id') == 'wo', orElse: () => {'title': 'Workout'});
  final n = d?.m('nutrition');
  final left = n == null ? 0 : (n.m('targets').i('protein') - n.m('eaten').i('protein')).clamp(0, 999);
  final w = d?.m('water');
  final pp = d?.m('preplan');
  final weight = context.app.me.d('weight_kg');
  final cards = [
    (Icons.fitness_center_rounded, 'Workout', wo.s('title'), !ok('wo'), 'workout'),
    (Icons.restaurant_outlined, 'Meal', '$left g protein left', ok('wo') && !ok('diet'), 'meal'),
    (Icons.water_drop_outlined, 'Water', '${w?.i('glasses') ?? 0} of ${w?.i('goal') ?? 8} glasses', false, 'water'),
    (Icons.monitor_weight_outlined, 'Weight', context.app.units.weight(weight), false, 'weight'),
    (Icons.monitor_heart_outlined, 'Activity', 'Track live with GPS or log one', false, 'activity'),
    (Icons.event_outlined, 'Pre-plan', pp != null && pp.b('saved') ? '${pp.s('occasion')} · saved' : 'Eating out later?', false, 'preplan'),
  ];
  final hi = cards.indexWhere((c) => c.$4);
  return showXSheet(
    context,
    (ctx) => XSheetBody(children: [
      XSheetHead(context.genz ? 'Fuel up' : 'Log', sub: 'What do you want to record?'),
      XGrid(cols: 3, gap: 10, children: [
        for (var i = 0; i < cards.length; i++)
          XOption(
            icon: cards[i].$1,
            title: cards[i].$2,
            sub: cards[i].$3,
            highlight: i == hi,
            onTap: () async {
              Navigator.pop(ctx);
              switch (cards[i].$5) {
                case 'workout':
                  Go.session(context, DateTime.now().weekday - 1);
                case 'meal':
                  Go.meal(context);
                case 'water':
                  final r = await attempt(context, () => Api.i.post('water/', {'delta': 1}));
                  if (r != null && context.mounted) {
                    final m = (r as Map)['message'];
                    context.say('$m'.isNotEmpty ? '$m' : 'Glass logged · ${r['glasses']} of ${r['goal']}');
                    context.app.changed();
                  }
                case 'weight':
                  showWeightSheet(context);
                case 'activity':
                  Go.track(context);
                case 'preplan':
                  Go.preplan(context);
              }
            },
          ),
      ]),
      gap16,
      Align(
        alignment: Alignment.centerLeft,
        child: XLink('Or share something: post, reel, story or challenge', onTap: () {
          Navigator.pop(ctx);
          showCreateSheet(context);
        }),
      ),
    ]),
  );
}

/// Weight: ± 0.1 kg steps, then targets update.
Future<void> showWeightSheet(BuildContext context) {
  var kg = context.app.me.d('weight_kg', 70);
  return showXSheet(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => XSheetBody(children: [
        const XSheetHead('Log weight'),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          XIconBtn(Icons.remove_rounded, tooltip: 'Less', onTap: () => set(() => kg = ((kg - .1) * 10).round() / 10)),
          const SizedBox(width: 12),
          Text(kg.toStringAsFixed(1), style: XT.hero(ctx).copyWith(fontSize: 72)),
          const SizedBox(width: 6),
          Text('kg', style: XT.small(ctx)),
          const SizedBox(width: 12),
          XIconBtn(Icons.add_rounded, tooltip: 'More', onTap: () => set(() => kg = ((kg + .1) * 10).round() / 10)),
        ]),
        gap12,
        Text('Weigh at the same time each morning. Used for trend lines only and never shown in the feed unless you change that in Settings.',
            style: XT.small(ctx)),
        gap16,
        XButton('Save weight', onTap: () async {
          Navigator.pop(ctx);
          final r = await attempt(context, () => Api.i.post('weight/', {'kg': kg.toStringAsFixed(1)}));
          if (r != null && context.mounted) {
            context.say('${(r as Map)['message']}');
            await context.app.refreshMe();
            if (context.mounted) context.app.changed();
          }
        }),
      ]),
    ),
  );
}

/// One-tap meals, logged to a slot (Exhaust Mode uses these).
Future<void> showQuickMealsSheet(BuildContext context, {String? slot}) async {
  Json d;
  try {
    d = Map<String, dynamic>.from(await Api.i.get('meals/') as Map);
  } on ApiError catch (e) {
    if (context.mounted) context.say(e.message);
    return;
  }
  if (!context.mounted) return;
  final s = slot ?? d.s('slot');
  return showXSheet(
    context,
    (ctx) => XSheetBody(children: [
      XSheetHead('One-tap meals', sub: 'Logs to ${s.toLowerCase()}.${d.b('exhaust') ? ' Exhaust Mode: protein goal only, at 80%.' : ''}'),
      for (final f in d.l('saved'))
        XRow(f.s('name'), sub: f.s('sub'), trailing: Text('${f.i('kcal')} kcal · ${f.i('protein')} g', style: XT.small(ctx)), onTap: () async {
          Navigator.pop(ctx);
          final r = await attempt(context, () => Api.i.post('meals/', {'source': 'saved', 'food_id': f.i('id'), 'slot': s}));
          if (r != null && context.mounted) {
            context.say('${(r as Map)['message']}');
            context.app.changed();
          }
        }),
      gap16,
      XButton('Scan instead', icon: Icons.document_scanner_outlined, kind: XBtn.secondary, onTap: () {
        Navigator.pop(ctx);
        Go.scan(context, slot: s);
      }),
    ]),
  );
}

/// Log a meal by hand: name, kcal, protein, carbs, slot.
Future<void> showManualMealSheet(BuildContext context) {
  final name = TextEditingController(), kcal = TextEditingController(), p = TextEditingController(), cbs = TextEditingController();
  final slots = context.app.catalog.strs('slots');
  final h = DateTime.now().hour;
  var slot = h < 11 ? 'Breakfast' : h < 15 ? 'Lunch' : h < 18 ? 'Snack' : 'Dinner';
  return showXSheet(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => XSheetBody(children: [
        const XSheetHead('Log a meal'),
        const XLabel('What did you eat'),
        gap8,
        XField(controller: name, hint: 'e.g. Curd rice and egg', autofocus: true),
        gap12,
        Row(children: [
          Expanded(child: _num(ctx, 'Kcal', kcal)),
          const SizedBox(width: 8),
          Expanded(child: _num(ctx, 'Protein g', p)),
          const SizedBox(width: 8),
          Expanded(child: _num(ctx, 'Carbs g', cbs)),
        ]),
        gap12,
        const XLabel('Meal'),
        gap8,
        Wrap(spacing: 8, runSpacing: 8, children: [for (final s in slots) XChip(s, on: s == slot, onTap: () => set(() => slot = s))]),
        gap20,
        XButton('Add meal', onTap: () async {
          final k = int.tryParse(kcal.text.trim()) ?? 0;
          if (name.text.trim().isEmpty || k <= 0) {
            context.say('Add a name and calories');
            return;
          }
          Navigator.pop(ctx);
          final r = await attempt(context, () => Api.i.post('meals/', {
                'source': 'manual',
                'name': name.text.trim(),
                'kcal': k,
                'protein': int.tryParse(p.text.trim()) ?? 0,
                'carbs': int.tryParse(cbs.text.trim()) ?? 0,
                'slot': slot,
              }));
          if (r != null && context.mounted) {
            context.say('${(r as Map)['message']}');
            context.app.changed();
          }
        }),
      ]),
    ),
  );
}

Widget _num(BuildContext ctx, String label, TextEditingController c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      XLabel(label),
      gap8,
      XField(controller: c, hint: '0', keyboard: TextInputType.number),
    ]);
