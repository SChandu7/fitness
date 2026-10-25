/// Number, time and unit formatting shared by every screen.
String fmtT(num seconds) {
  final s = seconds.round().clamp(0, 1 << 31);
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}' : '$m:${sec.toString().padLeft(2, '0')}';
}

String fmtN(num n) {
  final v = n.round();
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$b';
}

String fmt1(num v) => (v - v.round()).abs() < .05 ? fmtN(v) : v.toStringAsFixed(1);

/// Metric / Imperial, picked in Settings → Units.
class Units {
  final bool imperial;
  const Units(this.imperial);
  String weight(num kg) => imperial ? '${(kg * 2.20462).toStringAsFixed(1)} lb' : '${kg.toStringAsFixed(1)} kg';
  String dist(num km, {int digits = 2}) => imperial ? '${(km * 0.621371).toStringAsFixed(digits)} mi' : '${km.toStringAsFixed(digits)} km';
  String pace(num secPerKm) => imperial ? '${fmtT(secPerKm / 0.621371)} /mi' : '${fmtT(secPerKm)} /km';
  String volume(num litres) => imperial ? '${(litres * 33.814).round()} fl oz' : '${litres.toStringAsFixed(1)} L';
  String get distUnit => imperial ? 'mi' : 'km';
  num distValue(num km) => imperial ? km * 0.621371 : km;
}

String hourLabel(int h) => '${(h + 11) % 12 + 1} ${h < 12 ? 'am' : 'pm'}';

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((e) => e[0]).join().toUpperCase();
}
