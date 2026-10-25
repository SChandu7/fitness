import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Meal scan: photo → Gemini on the server → items, macros, allergy and meal-limit warnings.
class ScanScreen extends StatefulWidget {
  final String? slot;
  final bool barcode, fromLibrary;
  const ScanScreen({super.key, this.slot, this.barcode = false, this.fromLibrary = false});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum _Stage { camera, analyzing, result }

class _ScanScreenState extends State<ScanScreen> {
  _Stage _stage = _Stage.camera;
  Json _r = {};
  String _portion = 'Medium';
  String? _slot;
  final Set<String> _removed = {};
  bool _busy = false;
  late bool _barcode = widget.barcode;

  @override
  void initState() {
    super.initState();
    _slot = widget.slot;
    _portion = context.app.settingStr('portion', 'Medium');
    if (widget.fromLibrary || widget.barcode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(widget.fromLibrary ? ImageSource.gallery : ImageSource.camera));
    }
  }

  Future<void> _pick(ImageSource src) async {
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 85);
    } catch (_) {
      if (mounted) context.say(src == ImageSource.camera ? 'Camera is not available. Allow camera access in Settings.' : 'Could not open your photos.');
      return;
    }
    if (x == null || !mounted) return;
    setState(() => _stage = _Stage.analyzing);
    try {
      final r = await Api.i.upload('meals/scan/', fields: {
        'kind': _barcode ? 'barcode' : 'plate',
        'portion': _portion,
        if (_slot != null) 'slot': _slot!,
      }, files: {'image': File(x.path)});
      if (!mounted) return;
      setState(() {
        _r = Map<String, dynamic>.from(r as Map);
        _slot ??= _r.s('slot');
        _removed.clear();
        _stage = _Stage.result;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      context.say(e.message);
      setState(() => _stage = _Stage.camera);
    }
  }

  Future<void> _preview() async {
    try {
      final r = await Api.i.post('meals/scan/${_r.i('scan_id')}/preview/', {'portion': _portion, 'removed': _removed.toList(), 'slot': _slot});
      if (mounted) setState(() => _r = Map<String, dynamic>.from(r as Map));
    } on ApiError catch (e) {
      if (mounted) context.say(e.message);
    }
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    final r = await attempt(context, () => Api.i.post('meals/', {
          'source': 'scan',
          'scan_id': _r.i('scan_id'),
          'portion': _portion,
          'removed': _removed.toList(),
          'slot': _slot,
        }));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      context.say('${(r as Map)['message']}');
      context.app.changed();
      Navigator.pop(context);
    }
  }

  Future<void> _savePlate() async {
    final r = await attempt(context, () => Api.i.post('foods/', {'scan_id': _r.i('scan_id'), 'portion': _portion, 'removed': _removed.toList()}));
    if (r != null && mounted) {
      context.say('${(r as Map)['message']}');
      context.app.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_stage) {
      _Stage.camera => _camera(),
      _Stage.analyzing => _analyzing(),
      _Stage.result => _result(),
    };
  }

  Widget _camera() {
    const white = Color(0xFFFFFFFF);
    final dim = white.withValues(alpha: .72);
    final allergies = context.app.me.strs('allergies');
    final other = context.app.me.s('allergy_other');
    final all = [...allergies, if (other.isNotEmpty) other];
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: white), tooltip: 'Close'),
              Expanded(child: Text(_barcode ? 'Scan a pack' : 'Scan a plate', textAlign: TextAlign.center, style: XT.h3(context, color: white))),
              const SizedBox(width: 48),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF555555), width: 2)),
                  child: Icon(_barcode ? Icons.qr_code_scanner_rounded : Icons.restaurant_rounded, size: 72, color: const Color(0xFF333333)),
                ),
                gap24,
                Text(_barcode ? 'Fill the frame with the nutrition label or the front of the pack.' : 'Fit the whole plate in the frame. Good light helps.',
                    textAlign: TextAlign.center, style: XT.small(context, color: dim)),
                if (all.isNotEmpty) ...[
                  gap16,
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: context.c.red, width: 1.5)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('!', style: TextStyle(color: context.c.red, fontWeight: FontWeight.w700, fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Allergy reminder: ${all.join(', ')}. Check every item on the plate before you eat.', style: XT.small(context, color: white))),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(XS.gutter, 0, XS.gutter, 12),
            child: Row(children: [
              Expanded(child: _camOpt(Icons.qr_code_2_rounded, 'Barcode', _barcode, () => setState(() => _barcode = true))),
              const SizedBox(width: 8),
              Expanded(child: _camOpt(Icons.camera_alt_outlined, 'Scan meal', !_barcode, () => setState(() => _barcode = false))),
              const SizedBox(width: 8),
              Expanded(child: _camOpt(Icons.image_outlined, 'Library', false, () => _pick(ImageSource.gallery))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 28, top: 8),
            child: Semantics(
              button: true,
              label: 'Take photo',
              child: Press(
                onTap: () => _pick(ImageSource.camera),
                haptic: true,
                child: Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: white, width: 3)),
                  child: Container(decoration: const BoxDecoration(color: white, shape: BoxShape.circle)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _camOpt(IconData i, String l, bool on, VoidCallback onTap) {
    const white = Color(0xFFFFFFFF);
    return Press(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: on ? white.withValues(alpha: .14) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(i, size: 20, color: white),
          const SizedBox(height: 3),
          Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.small(context, color: white).copyWith(fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _analyzing() => Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFFFFFF))),
            gap16,
            Text(_barcode ? 'Reading the pack' : 'Reading your plate', style: XT.small(context, color: const Color(0xB8FFFFFF))),
          ]),
        ),
      );

  Widget _result() {
    final c = context.c;
    final t = _r.m('totals');
    final items = _r.l('items');
    final slots = context.app.catalog.strs('slots');
    if (_r.b('no_food')) {
      return XScreen(
        body: Column(children: [
          const XTopBar('Your plate'),
          const Expanded(child: XEmpty(icon: Icons.no_food_outlined, title: 'No food found', body: 'Try again with the whole plate in frame and good light.')),
        ]),
        dock: XDock(children: [XButton('Retake', onTap: () => setState(() => _stage = _Stage.camera))]),
      );
    }
    return XScreen(
      body: Column(children: [
        XTopBar(_r.s('kind') == 'barcode' ? 'Packaged food' : 'Your plate', actions: [
          XIconBtn(Icons.bookmark_border_rounded, tooltip: 'Save as a regular meal', onTap: _savePlate),
        ]),
        Expanded(
          child: XPage(children: [
            if (_r.b('is_sample')) ...[
              const XNote(text: 'Sample result. The AI scan was not available, so this is an example plate. Check the items before you log.'),
              gap12,
            ],
            XKicker('${_r.i('count')} item${_r.i('count') == 1 ? '' : 's'} found${_r.s('confidence').isNotEmpty && !_r.b('is_sample') ? ' · ${_r.s('confidence').toLowerCase()}' : ''}'),
            gap8,
            Text(_r.s('meal_name'), style: XT.h3(context)),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('${t.i('kcal')}', style: XT.hero(context).copyWith(fontSize: 72)),
              const SizedBox(width: 6),
              Text('kcal', style: XT.small(context)),
            ]),
            gap12,
            Row(children: [
              Expanded(child: XStat('Protein', '${t.i('protein')} g', size: 20)),
              Expanded(child: XStat('Carbs', '${t.i('carbs')} g', size: 20)),
              Expanded(child: XStat('Fat', '${t.i('fat')} g', size: 20)),
            ]),
            gap12,
            for (final it in items)
              Press(
                onTap: () {
                  setState(() => _removed.contains(it.s('key')) ? _removed.remove(it.s('key')) : _removed.add(it.s('key')));
                  _preview();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                  child: Opacity(
                    opacity: it.b('removed') ? .45 : 1,
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(it.s('name'), style: XT.h3(context).copyWith(fontSize: 15, decoration: it.b('removed') ? TextDecoration.lineThrough : null)),
                          const SizedBox(height: 2),
                          Text.rich(TextSpan(children: [
                            TextSpan(text: it.s('portion')),
                            if (it.strs('allergy').isNotEmpty)
                              TextSpan(text: ' · contains ${it.strs('allergy').map((e) => e.toLowerCase()).join(', ')}',
                                  style: TextStyle(color: c.red, fontWeight: FontWeight.w500)),
                          ]), style: XT.small(context)),
                        ]),
                      ),
                      Text('${it.i('kcal_p')} kcal · ${it.i('protein_p')} g protein', style: XT.small(context)),
                      const SizedBox(width: 6),
                      Icon(it.b('removed') ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded, size: 18, color: c.muted),
                    ]),
                  ),
                ),
              ),
            gap8,
            Text('Tap an item to take it off the plate.', style: XT.small(context)),
            gap16,
            const XLabel('Add to'),
            gap8,
            Wrap(spacing: 8, runSpacing: 8, children: [for (final s in slots) XChip(s, on: _slot == s, onTap: () => setState(() => _slot = s))]),
            gap16,
            Row(children: [
              Expanded(child: Text('Portion · ${_portion.toLowerCase()}', style: XT.small(context))),
              SizedBox(
                width: 220,
                child: XSegment(height: 32, labels: const ['Small', 'Medium', 'Large'], index: const ['Small', 'Medium', 'Large'].indexOf(_portion), onPick: (i) {
                  setState(() => _portion = const ['Small', 'Medium', 'Large'][i]);
                  _preview();
                }),
              ),
            ]),
            gap16,
            for (final w in _r.l('warnings')) ...[_warning(w), gap12],
            Text('Portions are estimates. Tap Retake if something looks off, or save it as a regular meal.', style: XT.small(context)),
            gap8,
            Text(_r.s('nudge'), style: XT.small(context, color: c.ink)),
          ]),
        ),
        XDock(row: true, children: [
          XButton('Retake', kind: XBtn.secondary, onTap: () => setState(() => _stage = _Stage.camera)),
          XButton('Add to ${(_slot ?? 'meal').toLowerCase()}', loading: _busy, onTap: _r.i('count') == 0 ? null : _add),
        ]),
      ]),
    );
  }

  Widget _warning(Json w) {
    final c = context.c;
    if (w.s('kind') == 'allergy_ok') {
      return XCard(muted: true, child: Row(children: [const XDot(), const SizedBox(width: 10), Expanded(child: Text(w.s('text'), style: XT.small(context, color: c.ink)))]));
    }
    return XWarn(title: w.s('title'), children: [
      Text(w.s('text'), style: XT.small(context, color: c.ink)),
      for (final l in w.l('lists')) ...[
        gap8,
        Text(l.s('label'), style: XT.small(context, color: c.ink)),
        for (final s in l.l('steps')) Padding(padding: const EdgeInsets.only(top: 4), child: Text('· ${s.s('name')}: ${s.s('action')}', style: XT.small(context))),
      ],
    ]);
  }
}
