import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

// ===========================================================================
// Line chart (heart rate, SpO₂, pace)
// ===========================================================================

class XLineChart extends StatelessWidget {
  final List<num> values;
  final double height;
  final double? min, max, threshold;
  final String? thresholdLabel;
  final bool zoneBand, peakDot;
  final Color? color;
  final String semantics;
  const XLineChart(this.values,
      {super.key,
      this.height = 110,
      this.min,
      this.max,
      this.threshold,
      this.thresholdLabel,
      this.zoneBand = false,
      this.peakDot = false,
      this.color,
      this.semantics = 'Chart'});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (values.length < 2) return SizedBox(height: height);
    return Semantics(
      label: semantics,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(values.map((e) => e.toDouble()).toList(), min, max, threshold, thresholdLabel, zoneBand, peakDot,
              color ?? c.ink, c.orange, c.gray, c.muted),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> v;
  final double? lo, hi, thr;
  final String? thrLabel;
  final bool band, peak;
  final Color line, accent, bandColor, muted;
  _LinePainter(this.v, this.lo, this.hi, this.thr, this.thrLabel, this.band, this.peak, this.line, this.accent, this.bandColor, this.muted);

  @override
  void paint(Canvas canvas, Size s) {
    final mn = lo ?? v.reduce(math.min);
    final mx = hi ?? v.reduce(math.max);
    final rg = math.max(1.0, mx - mn);
    double y(double val) => s.height - 6 - ((val.clamp(mn, mx) - mn) / rg) * (s.height - 14);
    if (band) {
      final h = s.height * .24;
      canvas.drawRect(Rect.fromLTWH(0, 0, s.width, h), Paint()..color = bandColor);
      _text(canvas, 'ZONE 5', Offset(6, h - 15), muted, 10);
    }
    if (thr != null) {
      final ty = y(thr!);
      final dash = Paint()
        ..color = accent
        ..strokeWidth = 1;
      for (double x = 0; x < s.width; x += 8) {
        canvas.drawLine(Offset(x, ty), Offset(math.min(s.width, x + 4), ty), dash);
      }
      if (thrLabel != null) _text(canvas, thrLabel!, Offset(s.width - 70, ty - 14), muted, 9.5, right: s.width - 4);
    }
    final n = v.length;
    final path = Path();
    var peakI = 0;
    for (var i = 0; i < n; i++) {
      final p = Offset(i / (n - 1) * s.width, y(v[i]));
      if (v[i] > v[peakI]) peakI = i;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.75
          ..strokeJoin = StrokeJoin.round);
    if (peak) {
      canvas.drawCircle(Offset(peakI / (n - 1) * s.width, y(v[peakI])), 5, Paint()..color = accent);
    }
  }

  void _text(Canvas canvas, String t, Offset o, Color color, double size, {double? right}) {
    final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, right != null ? Offset(right - tp.width, o.dy) : o);
  }

  @override
  bool shouldRepaint(_LinePainter o) => o.v != v || o.line != line;
}

/// Heart-rate chart with the zone-5 band, peak dot and start/peak/end labels.
class HrChart extends StatelessWidget {
  final List<num> hr;
  final int maxHr;
  final double height;
  const HrChart({super.key, required this.hr, required this.maxHr, this.height = 110});
  @override
  Widget build(BuildContext context) {
    final peak = hr.isEmpty ? 0 : hr.reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      XLineChart(hr, height: height, min: 80, max: maxHr + 5.0, zoneBand: true, peakDot: true,
          semantics: 'Heart rate over the session, peak $peak bpm'),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Start', style: XT.small(context)),
        Text('Peak $peak bpm', style: XT.small(context)),
        Text('End', style: XT.small(context)),
      ]),
    ]);
  }
}

/// Minutes in each heart-rate zone.
class ZoneRow extends StatelessWidget {
  final List<int> zones;
  const ZoneRow(this.zones, {super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < 5; i++)
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Z${i + 1}', style: XT.label(context).copyWith(fontSize: 10)),
              const SizedBox(height: 4),
              Text('${i < zones.length ? zones[i] : 0}m', style: XT.small(context, color: context.c.ink).copyWith(fontWeight: FontWeight.w500)),
            ]),
          ),
      ]);
}

/// Weekly bars (training minutes).
class WeekBars extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  final double height;
  const WeekBars({super.key, required this.values, required this.labels, this.height = 120});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mx = values.isEmpty ? 1 : math.max(1, values.reduce(math.max));
    return SizedBox(
      height: height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                AnimatedContainer(
                  duration: context.anim(XS.slow),
                  height: (values[i] / mx * (height - 24)).clamp(2, height - 24).toDouble(),
                  decoration: BoxDecoration(
                      color: i == values.length - 1 ? c.orange : c.ink, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 6),
                Text(labels[i], style: XT.small(context).copyWith(fontSize: 10)),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ===========================================================================
// Route map — draws GPS points (lat, lon) on a quiet street grid
// ===========================================================================

Color segmentColor(BuildContext context, double v) {
  final c = context.c;
  return v < .33 ? c.faint : (v < .7 ? c.ink : c.orange);
}

class RouteMap extends StatelessWidget {
  final List<List<double>> points;
  final double height;
  final List<double>? colors; // 0..1 per point for pace / heart-rate colouring
  final bool live, thin, kmMarks;
  final double? distanceKm;
  final int seed;
  final List<List<List<double>>>? overlays; // extra routes (all routes screen)
  const RouteMap(
      {super.key,
      required this.points,
      this.height = 220,
      this.colors,
      this.live = false,
      this.thin = false,
      this.kmMarks = false,
      this.distanceKm,
      this.seed = 7,
      this.overlays});

  static List<List<double>> parse(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<List>()
        .where((p) => p.length >= 2)
        .map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()])
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final segCols = colors == null ? null : [for (final v in colors!) segmentColor(context, v)];
    return Semantics(
      label: distanceKm != null ? 'Route map, ${distanceKm!.toStringAsFixed(2)} km' : 'Route map',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _RoutePainter(points, overlays, segCols, live, thin, kmMarks, distanceKm, seed,
              bg: c.gray, street: c.bg, canal: c.line, route: c.orange, mark: c.ink, onMark: c.bg, overlay: c.ink),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<List<double>> pts;
  final List<List<List<double>>>? overlays;
  final List<Color>? cols;
  final bool live, thin, kmMarks;
  final double? km;
  final int seed;
  final Color bg, street, canal, route, mark, onMark, overlay;
  _RoutePainter(this.pts, this.overlays, this.cols, this.live, this.thin, this.kmMarks, this.km, this.seed,
      {required this.bg, required this.street, required this.canal, required this.route, required this.mark, required this.onMark, required this.overlay});

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = bg);
    final all = <List<double>>[...pts, for (final o in overlays ?? const <List<List<double>>>[]) ...o];
    if (all.length < 2) return;
    // project lat/lon to metres around the centre
    final lat0 = all.map((p) => p[0]).reduce((a, b) => a + b) / all.length;
    final kx = 111320 * math.cos(lat0 * math.pi / 180), ky = 110540.0;
    Offset m(List<double> p) => Offset(p[1] * kx, -p[0] * ky);
    final ms = all.map(m).toList();
    var x0 = ms.first.dx, x1 = x0, y0 = ms.first.dy, y1 = y0;
    for (final o in ms) {
      x0 = math.min(x0, o.dx);
      x1 = math.max(x1, o.dx);
      y0 = math.min(y0, o.dy);
      y1 = math.max(y1, o.dy);
    }
    final pad = s.height < 80 ? 6.0 : 22.0;
    final scale = math.min((s.width - pad * 2) / math.max(60, x1 - x0), (s.height - pad * 2) / math.max(60, y1 - y0));
    final ox = (s.width - (x1 - x0) * scale) / 2, oy = (s.height - (y1 - y0) * scale) / 2;
    Offset P(List<double> p) {
      final o = m(p);
      return Offset(ox + (o.dx - x0) * scale, oy + (o.dy - y0) * scale);
    }

    // canal + street grid every ~250 m
    final r = math.Random(seed);
    final canalPath = Path()
      ..moveTo(0, s.height * (.2 + r.nextDouble() * .6))
      ..cubicTo(s.width * .3, s.height * r.nextDouble(), s.width * .6, s.height * r.nextDouble(), s.width, s.height * (.2 + r.nextDouble() * .6));
    canvas.drawPath(canalPath, Paint()
      ..color = canal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16);
    final step = 250 * scale;
    if (step > 14) {
      final sp = Paint()
        ..color = street
        ..strokeWidth = (step * .16).clamp(1.2, 5);
      final gx = ((ox - x0 * scale) % step + step) % step, gy = ((oy - y0 * scale) % step + step) % step;
      for (var v = gx; v < s.width; v += step) {
        canvas.drawLine(Offset(v, 0), Offset(v, s.height), sp);
      }
      for (var v = gy; v < s.height; v += step) {
        canvas.drawLine(Offset(0, v), Offset(s.width, v), sp);
      }
    }
    for (final o in overlays ?? const <List<List<double>>>[]) {
      if (o.length < 2) continue;
      final path = Path()..moveTo(P(o.first).dx, P(o.first).dy);
      for (final p in o.skip(1)) {
        path.lineTo(P(p).dx, P(p).dy);
      }
      canvas.drawPath(path, Paint()
        ..color = overlay.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round);
    }
    if (pts.length < 2) return;
    final pp = pts.map(P).toList();
    final w = thin ? 2.5 : 3.5;
    if (cols != null && cols!.length >= pp.length) {
      for (var i = 1; i < pp.length; i++) {
        canvas.drawLine(pp[i - 1], pp[i], Paint()
          ..color = cols![i]
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
      }
    } else {
      final path = Path()..moveTo(pp.first.dx, pp.first.dy);
      for (final p in pp.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, Paint()
        ..color = route
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round);
    }
    if (kmMarks && km != null && km! >= 1) {
      final every = km! > 20 ? 5 : 1;
      for (var k = every; k < km!; k += every) {
        final q = pp[((k / km!) * (pp.length - 1)).round().clamp(0, pp.length - 1)];
        canvas.drawCircle(q, 8, Paint()..color = onMark);
        canvas.drawCircle(q, 8, Paint()
          ..color = mark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        final tp = TextPainter(
            text: TextSpan(text: '$k', style: TextStyle(color: mark, fontSize: 9, fontWeight: FontWeight.w600)),
            textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas, q - Offset(tp.width / 2, tp.height / 2));
      }
    }
    if (thin) return;
    final a = pp.first, z = pp.last;
    canvas.drawCircle(a, 6, Paint()..color = mark);
    canvas.drawCircle(a, 2.5, Paint()..color = onMark);
    if (live) {
      canvas.drawCircle(z, 11, Paint()..color = route.withValues(alpha: .25));
      canvas.drawCircle(z, 6, Paint()..color = onMark);
      canvas.drawCircle(z, 4.5, Paint()..color = route);
    } else {
      final rect = Rect.fromCenter(center: z, width: 10, height: 10);
      canvas.drawRect(rect.inflate(2), Paint()..color = onMark);
      canvas.drawRect(rect, Paint()..color = mark);
    }
  }

  @override
  bool shouldRepaint(_RoutePainter o) => o.pts.length != pts.length || o.cols != cols || o.bg != bg;
}
