import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Home → "Your focus" poster: today's planned session, or the user's own focus for the day.
class FocusPoster extends StatefulWidget {
  final Json poster;
  const FocusPoster(this.poster, {super.key});
  @override
  State<FocusPoster> createState() => _FocusPosterState();
}

class _FocusPosterState extends State<FocusPoster> {
  late final _text = TextEditingController(text: widget.poster.s('focus'));
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save(String text) async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final r = await attempt(context, () => Api.i.post('day/focus/', {'text': text}));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      if (text.isEmpty) _text.clear();
      context.say('${(r as Map)['message']}');
      context.app.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = widget.poster;
    final custom = p.s('focus').isNotEmpty;
    const ink = Color(0xFFFFFFFF), dim = Color(0xFFD2D2D2), hot = Color(0xFFFFAD72);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Expanded(child: XLabel('Your focus today')), Text(custom ? 'Set by you' : 'From your plan', style: XT.small(context))]),
      gap8,
      Semantics(
        container: true,
        label: 'Focus poster: ${p.s('title')}. ${p.s('detail')}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF171717), Color(0xFF292929), Color(0xFF101010)]),
            ),
            child: Stack(children: [
              Positioned(
                right: -54,
                top: -72,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(center: Alignment(-.3, -.3), colors: [Color(0xFFFFB36D), Color(0xFFFF7A24), Color(0x14FF7A24)], stops: [0, .32, 1]),
                  ),
                ),
              ),
              Positioned(
                right: 22,
                top: 70,
                child: Transform.rotate(
                  angle: 18 * math.pi / 180,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Color(0xFFFFB36D), Color(0xFFFF6B1A), Color(0xFF9D3D0B)], stops: [0, .58, 1]),
                      boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(12, 16))],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x61FFFFFF))),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('EXERLIO / MOVE WITH PURPOSE', style: XT.label(context, color: hot).copyWith(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2))),
                    Text(p.s('stamp'), style: XT.label(context, color: dim).copyWith(fontSize: 10)),
                  ]),
                  const SizedBox(height: 22),
                  FractionallySizedBox(
                    widthFactor: .68,
                    child: Text(p.s('title'), maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: XT.h1(context, color: ink).copyWith(fontWeight: FontWeight.w800, height: 1.05, letterSpacing: -1.2)),
                  ),
                  gap8,
                  FractionallySizedBox(
                    widthFactor: .66,
                    child: Text([p.s('detail'), if (p.s('sub').isNotEmpty) p.s('sub')].join('\n'),
                        style: XT.small(context, color: dim).copyWith(fontSize: 12, height: 1.5)),
                  ),
                  const SizedBox(height: 24),
                  Container(height: 1, color: const Color(0x2EFFFFFF)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Text('SHOW UP. MOVE FORWARD.', style: XT.label(context, color: hot).copyWith(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2))),
                    Text(p.s('day'), style: XT.small(context, color: dim).copyWith(fontSize: 11)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
      gap12,
      Row(children: [
        Expanded(
          child: XField(
            controller: _text,
            hint: 'What do you want to do today?',
            action: TextInputAction.done,
            onSubmitted: (v) => v.trim().isEmpty ? null : _save(v.trim()),
          ),
        ),
        const SizedBox(width: 8),
        XButton('Set', expand: false, loading: _busy, onTap: () {
          final v = _text.text.trim();
          if (v.isEmpty) return context.say('Type what you want to focus on first');
          if (v.length > 72) return context.say('Keep it under 72 characters');
          _save(v);
        }),
      ]),
      gap4,
      if (custom)
        XLink('Use my scheduled plan instead', onTap: () => _save(''))
      else
        Text('Showing your plan. Type anything to make it your own focus for today.', style: XT.small(context, color: c.muted)),
    ]);
  }
}
