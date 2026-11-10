import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Tap an exercise: an animated movement preview, three form cues, and a variation you can keep.
Future<void> showExerciseDemo(BuildContext context, String name) async {
  Json d;
  try {
    d = Map<String, dynamic>.from(await Api.i.get('train/exercise/?name=${Uri.encodeQueryComponent(name)}') as Map);
  } on ApiError catch (e) {
    if (context.mounted) context.say(e.message);
    return;
  }
  if (!context.mounted) return;
  final changed = await showXSheet<bool>(context, (_) => _DemoSheet(d));
  if (changed == true && context.mounted) context.app.changed();
}

class _DemoSheet extends StatefulWidget {
  final Json d;
  const _DemoSheet(this.d);
  @override
  State<_DemoSheet> createState() => _DemoSheetState();
}

class _DemoSheetState extends State<_DemoSheet> {
  late String _pick = widget.d.s('chosen').isNotEmpty ? widget.d.s('chosen') : widget.d.strs('variations').first;
  bool _busy = false;

  Future<void> _save(String variation) async {
    setState(() => _busy = true);
    final r = await attempt(context, () => Api.i.post('train/exercise/', {'name': widget.d.s('name'), 'variation': variation}));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      context.say('${(r as Map)['message']}');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final c = context.c;
    final chosen = d.s('chosen');
    return XSheetBody(children: [
      const XKicker('Movement preview'),
      gap8,
      Text(d.s('name'), style: XT.h2(context)),
      gap12,
      ClipRRect(
        borderRadius: BorderRadius.circular(XS.r4),
        child: Container(
          height: 230,
          decoration: const BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -.25), radius: 1, colors: [Color(0xFF42464D), Color(0xFF202329), Color(0xFF111318)]),
          ),
          child: Stack(children: [
            Positioned.fill(child: MovementFigure(kind: d.s('kind'))),
            Positioned(
              right: 14,
              bottom: 10,
              child: Text('MOVEMENT PREVIEW', style: XT.label(context, color: const Color(0xFFBFC4CC)).copyWith(fontSize: 10)),
            ),
          ]),
        ),
      ),
      gap8,
      Text('A simple animation of the movement pattern, not a coaching video.', style: XT.small(context).copyWith(fontSize: 12)),
      gap16,
      const XLabel('Key form cues'),
      gap8,
      for (final (i, cue) in d.strs('cues').indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.orange, shape: BoxShape.circle),
              child: Text('${i + 1}', style: XT.small(context, color: const Color(0xFF000000)).copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(cue, style: XT.body(context))),
          ]),
        ),
      gap8,
      const XLabel('Choose a variation'),
      gap8,
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in d.strs('variations')) XChip(v, on: _pick == v, onTap: () => setState(() => _pick = v)),
      ]),
      gap8,
      Text('Your choice shows next to this exercise in your plan.', style: XT.small(context)),
      gap20,
      XButton(chosen == _pick ? 'Keep this variation' : 'Use this variation', loading: _busy,
          onTap: chosen == _pick ? () => Navigator.pop(context) : () => _save(_pick)),
      if (chosen.isNotEmpty) ...[gap8, XButton('Back to the planned exercise', kind: XBtn.secondary, onTap: () => _save(''))],
      gap16,
    ]);
  }
}

/// A side-view figure looping through one movement pattern. Stands still when Reduce motion is on.
class MovementFigure extends StatefulWidget {
  final String kind;
  const MovementFigure({super.key, required this.kind});
  @override
  State<MovementFigure> createState() => _MovementFigureState();
}

class _MovementFigureState extends State<MovementFigure> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: Duration(milliseconds: widget.kind == 'run' ? 900 : 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (XTheme.of(context).reduceMotion) {
      _a.value = .5;
      _a.stop();
    } else if (!_a.isAnimating) {
      _a.repeat();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (context, _) => CustomPaint(painter: _FigurePainter(widget.kind, _a.value, context.c.orange)),
      );
}

class _FigurePainter extends CustomPainter {
  final String kind;
  final double t;
  final Color accent;
  _FigurePainter(this.kind, this.t, this.accent);

  Offset _lerp(Offset a, Offset b, double e) => Offset.lerp(a, b, e)!;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 230;
    canvas.translate(size.width / 2 - 120 * s, 0);
    canvas.scale(s);
    final e = (1 - math.cos(2 * math.pi * t)) / 2; // 0 → 1 → 0
    final swing = math.sin(2 * math.pi * t);

    // standing defaults (side view, facing right)
    var head = const Offset(120, 42), shoulder = const Offset(120, 66), hip = const Offset(120, 118);
    var kneeA = const Offset(122, 156), kneeB = const Offset(118, 156), footA = const Offset(124, 194), footB = const Offset(116, 194);
    var elbowA = const Offset(124, 92), elbowB = const Offset(116, 92), handA = const Offset(126, 116), handB = const Offset(114, 116);
    var horizontal = false;

    switch (kind) {
      case 'squat':
        hip = _lerp(hip, const Offset(100, 146), e);
        shoulder = _lerp(shoulder, const Offset(128, 98), e);
        head = shoulder + const Offset(6, -24);
        kneeA = kneeB = _lerp(const Offset(120, 156), const Offset(140, 160), e);
        handA = handB = _lerp(const Offset(124, 116), const Offset(160, 96), e);
        elbowA = elbowB = Offset.lerp(shoulder, handA, .5)! + const Offset(0, 4);
      case 'hinge':
        hip = _lerp(hip, const Offset(100, 116), e);
        shoulder = _lerp(shoulder, const Offset(154, 98), e);
        head = shoulder + Offset(10 * e + 2, -24 + 10 * e);
        kneeA = kneeB = _lerp(const Offset(120, 156), const Offset(126, 156), e);
        handA = handB = Offset(shoulder.dx + 4, shoulder.dy + 50);
        elbowA = elbowB = Offset.lerp(shoulder, handA, .5)!;
      case 'push':
        handA = handB = _lerp(const Offset(140, 66), const Offset(172, 64), e);
        elbowA = elbowB = _lerp(const Offset(128, 86), const Offset(150, 66), e);
      case 'pull':
        handA = handB = _lerp(const Offset(172, 80), const Offset(132, 96), e);
        elbowA = elbowB = _lerp(const Offset(148, 76), const Offset(108, 92), e);
      case 'raise':
        // arm swings from hanging straight down to just above shoulder height
        final dir = Offset(math.sin(e * 1.6), math.cos(e * 1.6));
        elbowA = elbowB = shoulder + dir * 26;
        handA = handB = shoulder + dir * 52;
      case 'core':
        horizontal = true;
        final lift = 3 * swing;
        head = Offset(186, 132 + lift);
        shoulder = Offset(166, 142 + lift);
        hip = Offset(108, 150 + lift / 2);
        kneeA = kneeB = const Offset(82, 160);
        footA = footB = const Offset(56, 170);
        elbowA = elbowB = const Offset(166, 172);
        handA = handB = const Offset(184, 172);
      case 'run':
        shoulder = const Offset(124, 66);
        head = const Offset(127, 42);
        hip = Offset(120, 118 - 2 * swing.abs());
        kneeA = hip + Offset(20 * swing, 36);
        kneeB = hip + Offset(-20 * swing, 36);
        footA = kneeA + Offset(-6 + 8 * swing, 36);
        footB = kneeB + Offset(-6 - 8 * swing, 36);
        elbowA = shoulder + Offset(-16 * swing, 24);
        elbowB = shoulder + Offset(16 * swing, 24);
        handA = elbowA + Offset(10, 18);
        handB = elbowB + Offset(10, 18);
    }

    final shadow = Paint()..color = const Color(0x66000000);
    canvas.drawOval(Rect.fromCenter(center: const Offset(120, 200), width: horizontal ? 180 : 140, height: 16), shadow);
    final floor = Paint()
      ..color = const Color(0x38FFFFFF)
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(30, 196), const Offset(210, 196), floor);

    Paint limb(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const skinFar = Color(0xFF9D654E), skin = Color(0xFFE8B18F), shoe = Color(0xFFE6E7E8);

    void leg(Offset knee, Offset foot, Color col) {
      canvas.drawLine(hip, knee, limb(col, 15));
      canvas.drawLine(knee, foot, limb(col, 13));
      canvas.drawLine(foot, foot + const Offset(14, 0), limb(shoe, 9));
    }

    void arm(Offset elbow, Offset hand, Color col) {
      canvas.drawLine(shoulder, elbow, limb(col, 12));
      canvas.drawLine(elbow, hand, limb(col, 10));
    }

    leg(kneeB, footB, skinFar);
    arm(elbowB, handB, skinFar);
    // torso
    canvas.drawLine(shoulder, hip, limb(accent, 30));
    leg(kneeA, footA, skin);
    canvas.drawCircle(head, 14, Paint()..color = skin);
    arm(elbowA, handA, skin);
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.t != t || old.kind != kind;
}
