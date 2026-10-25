import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// Meal hub: Scan · Saved · Left today.
class MealScreen extends StatefulWidget {
  final int tab;
  const MealScreen({super.key, this.tab = 0});
  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  late int _tab = widget.tab;

  Future<void> _log(Json f) async {
    final r = await attempt(context, () => Api.i.post('meals/', {'source': 'saved', 'food_id': f.i('id')}));
    if (r != null && mounted) {
      context.say('${(r as Map)['message']}');
      context.app.changed();
    }
  }

  Future<void> _water() async {
    final r = await attempt(context, () => Api.i.post('water/', {'delta': 1}));
    if (r != null && mounted) {
      final m = '${(r as Map)['message']}';
      context.say(m.isNotEmpty ? m : 'Glass logged');
      context.app.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return XScreen(
      body: Column(children: [
        XTopBar('Meal', actions: [XIconBtn(Icons.event_outlined, tooltip: 'Pre-plan an outing', onTap: () => Go.preplan(context))]),
        Padding(
          padding: const EdgeInsets.fromLTRB(XS.gutter, 0, XS.gutter, 6),
          child: XSegment(labels: const ['Scan', 'Saved', 'Left today'], index: _tab, onPick: (i) => setState(() => _tab = i)),
        ),
        Expanded(
          child: Loader<Json>(
            load: () async => Map<String, dynamic>.from(await Api.i.get('meals/') as Map),
            builder: (context, d, reload) => switch (_tab) { 0 => _scan(d), 1 => _saved(d), _ => _left(d) },
          ),
        ),
      ]),
    );
  }

  Widget _scan(Json d) {
    final app = context.appWatch;
    final portion = app.settingStr('portion', 'Medium');
    return XPage(padding: const EdgeInsets.fromLTRB(XS.gutter, 12, XS.gutter, 32), children: [
      Text('Scan your meal', style: XT.h1(context)),
      gap16,
      Semantics(
        button: true,
        label: 'Open the camera and point at your plate',
        child: Press(
          onTap: () => Go.scan(context),
          child: Container(
            height: 280,
            decoration: BoxDecoration(color: const Color(0xFF000000), borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.all(18),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF444444), width: 2)),
              child: Text('CAMERA · POINT AT YOUR PLATE', style: XT.label(context, color: const Color(0xB8FFFFFF))),
            ),
          ),
        ),
      ),
      gap12,
      XGrid(cols: 3, children: [
        XOption(icon: Icons.qr_code_2_rounded, title: 'Barcode', center: true, onTap: () => Go.scan(context, barcode: true)),
        XOption(icon: Icons.camera_alt_outlined, title: 'Scan meal', center: true, onTap: () => Go.scan(context)),
        XOption(icon: Icons.image_outlined, title: 'Library', center: true, onTap: () => Go.scan(context, library: true)),
      ]),
      gap16,
      Row(children: [
        Expanded(child: Text('Portion estimate', style: XT.small(context))),
        SizedBox(
          width: 220,
          child: XSegment(height: 32, labels: const ['Small', 'Medium', 'Large'], index: const ['Small', 'Medium', 'Large'].indexOf(portion),
              onPick: (i) => app.setSetting('portion', const ['Small', 'Medium', 'Large'][i])),
        ),
      ]),
      gap12,
      Text('Get the whole plate in frame. It works out what is on it and how much, and you can correct anything it gets wrong.', style: XT.small(context)),
      gap16,
      XCard(
        onTap: () => setState(() => _tab = 1),
        child: Row(children: [
          const Icon(Icons.bookmark_border_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Saved meals', style: XT.h3(context).copyWith(fontSize: 15)),
              Text('Log a regular meal in one tap', style: XT.small(context)),
            ]),
          ),
          Text('${d.l('saved').length}', style: XT.small(context)),
        ]),
      ),
    ]);
  }

  Widget _saved(Json d) {
    final c = context.c;
    return XPage(padding: const EdgeInsets.fromLTRB(XS.gutter, 12, XS.gutter, 32), children: [
      Text('Saved meals', style: XT.h1(context)),
      gap4,
      Text('Your regulars. One tap logs them to ${d.s('slot').toLowerCase()}.', style: XT.small(context)),
      gap8,
      for (final f in d.l('saved'))
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.s('name'), style: XT.h3(context).copyWith(fontSize: 15)),
                Text(f.s('sub'), style: XT.small(context)),
                Text(f.s('macros'), style: XT.small(context).copyWith(fontSize: 12)),
                if (f.strs('allergy').isNotEmpty)
                  Text('Contains ${f.strs('allergy').map((e) => e.toLowerCase()).join(', ')}', style: XT.small(context, color: c.red).copyWith(fontSize: 12)),
              ]),
            ),
            if (f.b('mine'))
              XIconBtn(Icons.delete_outline_rounded, tooltip: 'Remove ${f.s('name')}', onTap: () async {
                final ok = await confirmX(context, title: 'Remove this saved meal?', body: f.s('name'), ok: 'Remove');
                if (!ok || !mounted) return;
                final r = await attempt(context, () => Api.i.delete('foods/${f.i('id')}/'));
                if (r != null && mounted) {
                  context.say('Removed from saved meals');
                  context.app.changed();
                }
              }),
            XButton('Log', icon: Icons.add_rounded, small: true, expand: false, kind: XBtn.secondary, onTap: () => _log(f)),
          ]),
        ),
      gap16,
      XButton('See what is left today', onTap: () => setState(() => _tab = 2)),
    ]);
  }

  Widget _left(Json d) {
    final c = context.c;
    final e = d.m('eaten'), t = d.m('targets'), left = d.m('left');
    final best = d.m('best');
    Widget row(String l, String k) {
      final v = e.i(k), tg = t.i(k);
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Expanded(child: Text(l, style: XT.h3(context).copyWith(fontSize: 15))),
            Text('${left.i(k)}', style: XT.metric(context, 26)),
            const SizedBox(width: 4),
            Text('g to go', style: XT.small(context)),
          ]),
          gap8,
          XBar(tg == 0 ? 0 : v / tg, color: goalColor(context, tg == 0 ? 0 : v / tg)),
          gap4,
          Text('$v of $tg g eaten${k == 'fat' ? ' · ${left.i('kcal')} kcal left overall' : ''}', style: XT.small(context)),
        ]),
      );
    }

    final glasses = d.i('glasses'), goal = t.i('glasses');
    return XPage(padding: const EdgeInsets.fromLTRB(XS.gutter, 12, XS.gutter, 32), children: [
      Text('Left for today', style: XT.h1(context)),
      gap4,
      Text('What you still need to hit today\'s diet goal. Updates as you log.${d.b('exhaust') ? ' Exhaust Mode: protein only, at 80%.' : ''}', style: XT.small(context)),
      gap20,
      row('Protein', 'protein'),
      row('Carbs', 'carbs'),
      row('Fat', 'fat'),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(child: Text('Hydration', style: XT.h3(context).copyWith(fontSize: 15))),
        Text(d.d('water_left_l').toStringAsFixed(1), style: XT.metric(context, 26)),
        const SizedBox(width: 4),
        Text('L to go', style: XT.small(context)),
        const SizedBox(width: 8),
        XIconBtn(Icons.add_rounded, tooltip: 'Log a glass', onTap: _water),
      ]),
      XBar(goal == 0 ? 0 : glasses / goal, color: goalColor(context, goal == 0 ? 0 : glasses / goal)),
      gap4,
      Text('${(goal - glasses).clamp(0, 99)} glasses left of $goal', style: XT.small(context)),
      if (best.isNotEmpty) ...[
        gap20,
        XNote(
          label: 'Closes the gap best',
          text: '',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(best.s('name'), style: XT.h3(context)),
            gap4,
            Text('${best.i('protein')} g protein · ${best.i('carbs')} g carbs · ${best.i('kcal')} kcal', style: XT.small(context)),
            gap12,
            XButton('Log it', small: true, expand: false, onTap: () => _log(best)),
          ]),
        ),
      ],
      if (d.l('micros').isNotEmpty) ...[
        gap20,
        Row(children: [
          const Expanded(child: XLabel('Vitamins and minerals')),
          Text('${d.l('micros').where((m) => m.b('low')).length} running low', style: XT.small(context)),
        ]),
        for (final m in d.l('micros'))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(m.s('label'), style: XT.h3(context).copyWith(fontSize: 15))), Text(m.s('line'), style: XT.small(context, color: c.ink))]),
              const SizedBox(height: 3),
              Row(children: [
                if (m.b('low')) ...[const XDot(), const SizedBox(width: 6)],
                Text(m.s('status'), style: XT.small(context, color: m.b('low') ? c.ink : null)),
              ]),
              if (m.s('tip').isNotEmpty) Text(m.s('tip'), style: XT.small(context).copyWith(fontSize: 12)),
            ]),
          ),
        gap12,
        Text('Food-first suggestions from your logs. If a nutrient stays low for weeks, check with your doctor before adding supplements.', style: XT.small(context)),
      ],
    ]);
  }
}
