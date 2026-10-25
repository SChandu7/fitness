import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'app_state.dart';
import 'theme.dart';

// ===========================================================================
// PRESS — scale to 0.98, 150 ms
// ===========================================================================

class Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;
  const Press({super.key, required this.child, this.onTap, this.haptic = false});
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => setState(() => _down = true) : null,
      onTapUp: on ? (_) => setState(() => _down = false) : null,
      onTapCancel: on ? () => setState(() => _down = false) : null,
      onTap: on
          ? () {
              if (widget.haptic && context.app.setting('haptics')) HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? .98 : 1,
        duration: context.anim(XS.fast),
        curve: XS.ease,
        child: widget.child,
      ),
    );
  }
}

// ===========================================================================
// BUTTONS
// ===========================================================================

enum XBtn { primary, accent, secondary, outline, ghost }

class XButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final XBtn kind;
  final IconData? icon;
  final bool loading, expand, small;
  const XButton(this.label,
      {super.key, this.onTap, this.kind = XBtn.primary, this.icon, this.loading = false, this.expand = true, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, border) = switch (kind) {
      XBtn.primary => (c.ink, c.onInk, Colors.transparent),
      XBtn.accent => (c.orange, const Color(0xFF000000), Colors.transparent),
      XBtn.secondary => (c.gray, c.ink, Colors.transparent),
      XBtn.outline => (Colors.transparent, c.ink, c.line),
      XBtn.ghost => (Colors.transparent, c.ink, Colors.transparent),
    };
    final disabled = onTap == null || loading;
    final h = small ? 40.0 : 52.0;
    return Press(
      onTap: disabled ? null : onTap,
      haptic: kind == XBtn.primary || kind == XBtn.accent,
      child: AnimatedOpacity(
        opacity: onTap == null ? .45 : 1,
        duration: context.anim(XS.fast),
        child: Container(
          height: h,
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(small ? XS.rSm : XS.r2),
            border: border == Colors.transparent ? null : Border.all(color: border),
          ),
          child: loading
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, size: small ? 16 : 18, color: fg), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: XT.button(context, color: fg).copyWith(fontSize: small ? 13 : 15)),
                  ),
                ]),
        ),
      ),
    );
  }
}

class XIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final bool dot;
  final String? tooltip;
  final Color? color;
  const XIconBtn(this.icon, {super.key, required this.onTap, this.badge = 0, this.dot = false, this.tooltip, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: tooltip,
      child: Press(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
            Icon(icon, size: 22, color: color ?? c.ink),
            if (badge > 0)
              Positioned(
                top: 6,
                right: 4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.orange, borderRadius: BorderRadius.circular(8)),
                  child: Text('$badge',
                      style: XT.label(context, color: const Color(0xFF000000)).copyWith(fontSize: 10, letterSpacing: 0)),
                ),
              )
            else if (dot)
              Positioned(
                top: 10,
                right: 10,
                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.orange, shape: BoxShape.circle)),
              ),
          ]),
        ),
      ),
    );
  }
}

// ===========================================================================
// CONTAINERS
// ===========================================================================

class XCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool muted, dark;
  final Color? color;
  const XCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      this.onTap,
      this.muted = false,
      this.dark = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (dark ? c.ink : (muted ? c.gray : c.surface)),
        borderRadius: BorderRadius.circular(context.genz ? XS.r4 : XS.r3),
        border: (muted || dark || color != null) ? null : Border.all(color: c.line),
      ),
      child: dark ? DefaultTextStyle.merge(style: TextStyle(color: c.onInk), child: child) : child,
    );
    return onTap == null ? body : Press(onTap: onTap, child: body);
  }
}

class XLabel extends StatelessWidget {
  final String text;
  final bool orange;
  final Color? color;
  const XLabel(this.text, {super.key, this.orange = false, this.color});
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: XT.label(context, color: color ?? (orange ? context.c.orange : null)));
}

class XSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;
  const XSection({super.key, required this.title, required this.child, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: XLabel(title)),
          if (action != null)
            Press(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(action!, style: XT.small(context, color: context.c.ink)),
              ),
            ),
        ]),
        const SizedBox(height: XS.s3),
        child,
      ]);
}

// ===========================================================================
// DATA
// ===========================================================================

class XBar extends StatelessWidget {
  final double value;
  final Color? color, track;
  final double height;
  const XBar(this.value, {super.key, this.color, this.track, this.height = 6});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: track ?? c.gray,
        alignment: Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (_, box) => AnimatedContainer(
            duration: context.anim(XS.slow),
            curve: XS.ease,
            width: box.maxWidth * value.clamp(0.0, 1.0),
            color: color ?? c.ink,
          ),
        ),
      ),
    );
  }
}

class XRing extends StatelessWidget {
  final double value;
  final double size, stroke;
  final Color? color;
  final Widget? center;
  const XRing({super.key, required this.value, this.size = 72, this.stroke = 6, this.color, this.center});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: context.anim(XS.slow * 2),
          curve: XS.ease,
          builder: (_, v, __) =>
              CustomPaint(size: Size(size, size), painter: _Ring(v, color ?? c.ink, c.gray, stroke)),
        ),
        if (center != null) center!,
      ]),
    );
  }
}

class _Ring extends CustomPainter {
  final double v;
  final Color fg, bg;
  final double stroke;
  _Ring(this.v, this.fg, this.bg, this.stroke);
  @override
  void paint(Canvas canvas, Size s) {
    final r = (s.width - stroke) / 2;
    final o = Offset(s.width / 2, s.height / 2);
    canvas.drawCircle(o, r, Paint()..color = bg..style = PaintingStyle.stroke..strokeWidth = stroke);
    canvas.drawArc(Rect.fromCircle(center: o, radius: r), -math.pi / 2, 2 * math.pi * v, false,
        Paint()..color = fg..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_Ring o) => o.v != v || o.fg != fg;
}

class XStat extends StatelessWidget {
  final String label, value;
  final String? unit;
  final double size;
  final Color? color;
  const XStat(this.label, this.value, {super.key, this.unit, this.size = 22, this.color});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        XLabel(label, color: color?.withValues(alpha: .7)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.metric(context, size, color: color))),
          if (unit != null) ...[
            const SizedBox(width: 3),
            Flexible(child: Text(unit!, maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.small(context, color: color?.withValues(alpha: .7)))),
          ],
        ]),
      ]);
}

class XAvatar extends StatelessWidget {
  final Json user;
  final double size;
  final bool square, ink;
  const XAvatar(this.user, {super.key, this.size = 40, this.square = false, this.ink = false});

  static Color _hex(String h, Color fallback) {
    final v = int.tryParse(h.replaceFirst('#', ''), radix: 16);
    return v == null ? fallback : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    var bg = ink ? c.ink : _hex(user.s('bg', user.s('avatar_bg')), c.gray);
    var fg = ink ? c.onInk : _hex(user.s('ink', user.s('avatar_ink')), c.ink);
    if (!ink && Theme.of(context).brightness == Brightness.dark && bg.computeLuminance() < .05) {
      bg = c.gray;
      fg = c.ink;
    }
    final name = user.s('name', '?');
    final initial = user.s('initial', name.isEmpty ? '?' : name[0]);
    final url = user.s('avatar');
    final radius = square ? BorderRadius.circular(size * .24) : BorderRadius.circular(size);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: radius, border: ink ? null : Border.all(color: c.line)),
      child: Text(initial, maxLines: 1, style: XT.h3(context, color: fg).copyWith(fontSize: size * .34, fontWeight: FontWeight.w600)),
    );
    if (url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

class XFaces extends StatelessWidget {
  final List<Json> users;
  final double size;
  const XFaces(this.users, {super.key, this.size = 26});
  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      width: size + (users.length - 1) * size * .66,
      child: Stack(children: [
        for (var i = 0; i < users.length; i++) Positioned(left: i * size * .66, child: XAvatar(users[i], size: size)),
      ]),
    );
  }
}

// ===========================================================================
// INPUTS
// ===========================================================================

class XChip extends StatelessWidget {
  final String label;
  final bool on, check, dashed;
  final VoidCallback? onTap;
  const XChip(this.label, {super.key, required this.on, this.onTap, this.check = false, this.dashed = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Press(
      onTap: onTap,
      child: AnimatedContainer(
        duration: context.anim(XS.fast),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: on ? c.ink : c.surface,
          borderRadius: BorderRadius.circular(XS.r1),
          border: Border.all(color: on ? c.ink : c.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (check && on) ...[Icon(Icons.check_rounded, size: 14, color: c.onInk), const SizedBox(width: 4)],
          Text(label, style: XT.small(context, color: on ? c.onInk : (dashed ? c.muted : c.ink)).copyWith(fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

/// Underlined text tabs (Scan · Saved · Left today).
class XTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onPick;
  final List<int>? counts;
  const XTabs({super.key, required this.labels, required this.index, required this.onPick, this.counts});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Press(
              onTap: () => onPick(i),
              child: Container(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                margin: const EdgeInsets.only(right: 22),
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: i == index ? c.ink : Colors.transparent, width: 2))),
                child: Row(children: [
                  Text(labels[i], style: XT.h3(context, color: i == index ? c.ink : c.muted).copyWith(fontSize: 15)),
                  if (counts != null && i < counts!.length) ...[
                    const SizedBox(width: 6),
                    Text('${counts![i]}', style: XT.small(context)),
                  ],
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Pill segmented control.
class XSegment extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onPick;
  final bool ink;
  final double height;
  const XSegment({super.key, required this.labels, required this.index, required this.onPick, this.ink = false, this.height = 36});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.gray, borderRadius: BorderRadius.circular(XS.r2)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Press(
              onTap: () => onPick(i),
              child: AnimatedContainer(
                duration: context.anim(XS.fast),
                height: height,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i == index ? (ink ? c.ink : c.surface) : Colors.transparent,
                  borderRadius: BorderRadius.circular(XS.rSm),
                  border: i == index && !ink ? Border.all(color: c.line) : null,
                ),
                child: Text(labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: XT.small(context, color: i == index ? (ink ? c.onInk : c.ink) : c.muted)
                        .copyWith(fontWeight: i == index ? FontWeight.w600 : FontWeight.w500)),
              ),
            ),
          ),
      ]),
    );
  }
}

class XSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const XSwitch({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      toggled: value,
      child: Press(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: context.anim(XS.fast),
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(color: value ? c.ink : c.gray2, borderRadius: BorderRadius.circular(13)),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Color(0x2E000000), offset: Offset(0, 1), blurRadius: 2)],
            ),
          ),
        ),
      ),
    );
  }
}

class XField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure, autofocus;
  final TextInputType? keyboard;
  final int maxLines;
  final ValueChanged<String>? onChanged, onSubmitted;
  final Widget? prefix;
  final TextInputAction? action;
  const XField(
      {super.key,
      required this.controller,
      this.hint = '',
      this.obscure = false,
      this.autofocus = false,
      this.keyboard,
      this.maxLines = 1,
      this.onChanged,
      this.onSubmitted,
      this.prefix,
      this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      constraints: BoxConstraints(minHeight: maxLines == 1 ? 52 : 100),
      decoration: BoxDecoration(color: c.gray, borderRadius: BorderRadius.circular(XS.r2)),
      child: Row(crossAxisAlignment: maxLines == 1 ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
        if (prefix != null) ...[prefix!, const SizedBox(width: 10)],
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            autofocus: autofocus,
            keyboardType: keyboard,
            maxLines: obscure ? 1 : maxLines,
            minLines: 1,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: action,
            style: XT.body(context),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: XT.body(context, color: c.faint),
              contentPadding: EdgeInsets.symmetric(vertical: maxLines == 1 ? 14 : 14),
            ),
          ),
        ),
      ]),
    );
  }
}

// ===========================================================================
// ROWS, BARS, STATES
// ===========================================================================

class XRow extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? leading, trailing;
  final VoidCallback? onTap;
  final bool chevron, divider;
  const XRow(this.title,
      {super.key, this.sub, this.leading, this.trailing, this.onTap, this.chevron = false, this.divider = true});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final row = Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: divider ? Border(bottom: BorderSide(color: c.line)) : null),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: XS.s3)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: XT.h3(context).copyWith(fontSize: 15)),
            if (sub != null && sub!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(sub!, style: XT.small(context)),
            ],
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: XS.s3), trailing!],
        if (chevron) Icon(Icons.chevron_right_rounded, size: 20, color: c.muted),
      ]),
    );
    return onTap == null ? row : Press(onTap: onTap, child: row);
  }
}

/// Screen header: back arrow + title, optional actions.
class XTopBar extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final bool back;
  const XTopBar(this.title, {super.key, this.actions = const [], this.onBack, this.back = true});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final canPop = back && Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: SizedBox(
        height: 52,
        child: Row(children: [
          if (canPop || onBack != null)
            XIconBtn(Icons.chevron_left_rounded, tooltip: 'Back', onTap: onBack ?? () => Navigator.of(context).maybePop())
          else
            const SizedBox(width: 16),
          Expanded(
            child: Text(title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.h3(context, color: c.ink).copyWith(fontSize: 17)),
          ),
          ...actions,
        ]),
      ),
    );
  }
}

class XEmpty extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final String? action;
  final VoidCallback? onAction;
  const XEmpty({super.key, required this.icon, required this.title, required this.body, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: XS.gutter),
        child: Column(children: [
          Icon(icon, size: 30, color: context.c.muted),
          const SizedBox(height: 14),
          Text(title, style: XT.h3(context), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(body, style: XT.small(context), textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 18),
            XButton(action!, onTap: onAction, kind: XBtn.secondary, expand: false, small: true),
          ],
        ]),
      );
}

class XError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const XError(this.message, {super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: XS.gutter),
        child: Column(children: [
          Icon(Icons.wifi_off_rounded, size: 28, color: context.c.muted),
          const SizedBox(height: 14),
          Text('Could not load this', style: XT.h3(context)),
          const SizedBox(height: 6),
          Text(message, style: XT.small(context), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          XButton('Try again', onTap: onRetry, kind: XBtn.secondary, expand: false, small: true),
        ]),
      );
}

class XSkeleton extends StatefulWidget {
  final int lines;
  const XSkeleton({super.key, this.lines = 4});
  @override
  State<XSkeleton> createState() => _XSkeletonState();
}

class _XSkeletonState extends State<XSkeleton> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) {
        final col = Color.lerp(c.gray, c.line, _a.value)!;
        Widget box(double h, [double? w]) => Container(
            height: h, width: w, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(XS.r3)));
        final body = Padding(
          padding: const EdgeInsets.all(XS.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            box(14, 120),
            const SizedBox(height: 14),
            box(30, 220),
            const SizedBox(height: 24),
            for (var i = 0; i < widget.lines; i++) ...[box(i == 0 ? 160 : 88), const SizedBox(height: 14)],
          ]),
        );
        // In a short box (stories row, sheet) clip instead of overflowing.
        return LayoutBuilder(
          builder: (_, box) => box.hasBoundedHeight
              ? SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: body)
              : body,
        );
      },
    );
  }
}

/// Loads data from the API, shows loading / error+retry, reloads when the app
/// signals a change, and supports pull-to-refresh.
class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final int skeletonLines;
  const Loader({super.key, required this.load, required this.builder, this.skeletonLines = 4});
  @override
  State<Loader<T>> createState() => LoaderState<T>();
}

class LoaderState<T> extends State<Loader<T>> {
  T? data;
  String? error;
  bool loading = true;
  int _version = -1;

  Future<void> reload() async {
    try {
      final v = await widget.load();
      if (!mounted) return;
      setState(() {
        data = v;
        error = null;
        loading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Something went wrong. Please try again.';
        loading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = context.appWatch.version;
    if (v != _version) {
      _version = v;
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null && loading) return XSkeleton(lines: widget.skeletonLines);
    if (data == null && error != null) {
      return Center(
        child: XError(error!, onRetry: () {
          setState(() => loading = true);
          reload();
        }),
      );
    }
    return RefreshIndicator(
      color: context.c.ink,
      backgroundColor: context.c.surface,
      onRefresh: reload,
      child: widget.builder(context, data as T, reload),
    );
  }
}

// ===========================================================================
// SHEETS, DIALOGS
// ===========================================================================

Future<T?> showXSheet<T>(BuildContext context, Widget Function(BuildContext) builder) {
  final c = context.c;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surface,
    barrierColor: Colors.black.withValues(alpha: .4),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(XS.r4))),
    builder: (ctx) => XTheme(
      c: XTheme.of(context).c,
      genz: XTheme.of(context).genz,
      reduceMotion: XTheme.of(context).reduceMotion,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: c.gray2, borderRadius: BorderRadius.circular(2))),
          Flexible(child: builder(ctx)),
        ]),
      ),
    ),
  );
}

Future<bool> confirmX(BuildContext context,
    {required String title, required String body, String ok = 'Confirm', String cancel = 'Cancel', bool danger = false}) async {
  final c = context.c;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(XS.r4)),
      child: Padding(
        padding: const EdgeInsets.all(XS.s5),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: XT.h2(context)),
          const SizedBox(height: 8),
          Text(body, style: XT.body(context, color: c.muted)),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: XButton(cancel, kind: XBtn.secondary, onTap: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 10),
            Expanded(child: XButton(ok, kind: danger ? XBtn.primary : XBtn.primary, onTap: () => Navigator.pop(ctx, true))),
          ]),
        ]),
      ),
    ),
  );
  return r ?? false;
}

/// Runs an API call, shows a toast on error. Returns null on failure.
Future<T?> attempt<T>(BuildContext context, Future<T> Function() run, {String? success}) async {
  try {
    final r = await run();
    if (success != null && context.mounted) context.say(success);
    return r;
  } on ApiError catch (e) {
    if (context.mounted) context.say(e.message);
  } catch (_) {
    if (context.mounted) context.say('Something went wrong. Please try again.');
  }
  return null;
}

/// Standard scrollable page body with the 24 px gutter.
class XPage extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const XPage({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(XS.gutter, 8, XS.gutter, 32)});
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: children,
      );
}

const gap4 = SizedBox(height: 4);
const gap8 = SizedBox(height: 8);
const gap12 = SizedBox(height: 12);
const gap16 = SizedBox(height: 16);
const gap20 = SizedBox(height: 20);
const gap24 = SizedBox(height: 24);
const gap32 = SizedBox(height: 32);

/// EXERLIO logotype with the orange action dot.
class Wordmark extends StatelessWidget {
  final double size;
  const Wordmark({super.key, this.size = 15});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('EXERLIO',
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w300, letterSpacing: size * .2, color: context.c.ink)),
        SizedBox(width: size * .3),
        Container(
            width: size * .4, height: size * .4, decoration: BoxDecoration(color: context.c.orange, shape: BoxShape.circle)),
      ]);
}

// ===========================================================================
// v3 PIECES
// ===========================================================================

/// The orange action dot.
class XDot extends StatelessWidget {
  final double size;
  final Color? color;
  const XDot({super.key, this.size = 7, this.color});
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color ?? context.c.orange, shape: BoxShape.circle));
}

/// Label with a leading orange dot: "● RECOVERY · TODAY".
class XKicker extends StatelessWidget {
  final String text;
  final bool dot;
  final Color? color;
  const XKicker(this.text, {super.key, this.dot = true, this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[const XDot(), const SizedBox(width: 7)],
        Flexible(child: Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.label(context, color: color))),
      ]);
}

/// Round tick used in plans and checklists.
class XCheck extends StatelessWidget {
  final bool done, next;
  final bool inverted;
  const XCheck({super.key, required this.done, this.next = false, this.inverted = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fill = inverted ? c.onInk : c.ink;
    return AnimatedContainer(
      duration: context.anim(XS.fast),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? fill : Colors.transparent,
        border: Border.all(color: done ? fill : (next ? c.orange : (inverted ? c.onInk.withValues(alpha: .4) : c.gray2)), width: 1.5),
      ),
      child: done
          ? Icon(Icons.check_rounded, size: 15, color: inverted ? c.ink : c.onInk)
          : (next ? const XDot(size: 7) : null),
    );
  }
}

/// Muted grey card with an ink label: guidance and explanations.
class XNote extends StatelessWidget {
  final String? label;
  final String text;
  final bool dot;
  final Widget? child;
  const XNote({super.key, this.label, required this.text, this.dot = false, this.child});
  @override
  Widget build(BuildContext context) => XCard(
        muted: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label != null) ...[XKicker(label!, dot: dot, color: context.c.ink), gap8],
          if (text.isNotEmpty) Text(text, style: XT.small(context, color: context.c.ink)),
          if (child != null) ...[if (text.isNotEmpty || label != null) gap12, child!],
        ]),
      );
}

/// Red-bordered warning box (allergies, meal limits, health).
class XWarn extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const XWarn({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: c.redBg, borderRadius: BorderRadius.circular(XS.r3), border: Border.all(color: c.red, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        XKicker(title, color: c.red),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }
}

/// Four rising bars + intensity name (Light / Moderate / Heavy / Extreme).
class XIntensity extends StatelessWidget {
  final String level;
  final bool showLabel;
  const XIntensity(this.level, {super.key, this.showLabel = true});
  static const levels = ['Light', 'Moderate', 'Heavy', 'Extreme'];
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = levels.indexOf(level) + 1;
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var x = 1; x <= 4; x++)
        Container(
          width: 4,
          height: 4 + x * 3.0,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
              color: x <= n ? (n == 4 ? c.orange : c.ink) : c.gray2, borderRadius: BorderRadius.circular(1)),
        ),
      if (showLabel) ...[const SizedBox(width: 4), Text(level, style: XT.small(context, color: c.ink).copyWith(fontWeight: FontWeight.w500))],
    ]);
  }
}

/// Grey stat box: LABEL over a value.
class XStatBox extends StatelessWidget {
  final String label, value;
  final String? sub, unit;
  final EdgeInsets padding;
  const XStatBox(this.label, this.value, {super.key, this.sub, this.unit, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => XCard(
        muted: true,
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), maxLines: 2, style: XT.label(context)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(value, style: XT.metric(context, 19)),
              if (unit != null) ...[const SizedBox(width: 3), Text(unit!, style: XT.small(context).copyWith(fontSize: 11))],
            ]),
          ),
          if (sub != null && sub!.isNotEmpty) ...[const SizedBox(height: 4), Text(sub!, style: XT.small(context).copyWith(fontSize: 12))],
        ]),
      );
}

/// Equal-width grid that wraps (2, 3 or 4 columns).
class XGrid extends StatelessWidget {
  final int cols;
  final double gap;
  final List<Widget> children;
  const XGrid({super.key, required this.cols, required this.children, this.gap = 8});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

/// Tappable option tile used in the Create and Share sheets.
class XOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  final VoidCallback onTap;
  final bool highlight, center;
  const XOption({super.key, required this.icon, required this.title, this.sub, required this.onTap, this.highlight = false, this.center = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = highlight ? c.onInk : c.ink;
    return Press(
      onTap: onTap,
      haptic: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlight ? c.ink : c.surface,
          borderRadius: BorderRadius.circular(context.genz ? XS.r4 : XS.r3),
          border: highlight ? null : Border.all(color: c.line),
        ),
        child: Column(
            crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 10),
              Text(title, textAlign: center ? TextAlign.center : TextAlign.start, style: XT.h3(context, color: fg).copyWith(fontSize: 14.5)),
              if (sub != null) ...[
                const SizedBox(height: 3),
                Text(sub!, style: XT.small(context, color: highlight ? c.onInk.withValues(alpha: .72) : c.muted).copyWith(fontSize: 12)),
              ],
            ]),
      ),
    );
  }
}

/// Horizontal scroller with the page gutter.
class XHScroll extends StatelessWidget {
  final List<Widget> children;
  final double gap;
  final EdgeInsets padding;
  const XHScroll({super.key, required this.children, this.gap = 8, this.padding = const EdgeInsets.symmetric(horizontal: XS.gutter)});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), children[i]],
        ]),
      );
}

/// Title + optional subtitle at the top of a bottom sheet.
class XSheetHead extends StatelessWidget {
  final String title;
  final String? sub;
  const XSheetHead(this.title, {super.key, this.sub});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: XT.h2(context)),
          if (sub != null && sub!.isNotEmpty) ...[const SizedBox(height: 4), Text(sub!, style: XT.small(context))],
        ]),
      );
}

/// Scrollable padded body for bottom sheets.
class XSheetBody extends StatelessWidget {
  final List<Widget> children;
  const XSheetBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(XS.gutter, 4, XS.gutter, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
      );
}

/// Radio-style choice card used in setup and sheets.
class XChoice extends StatelessWidget {
  final String title;
  final String? sub;
  final bool on;
  final VoidCallback onTap;
  final IconData? icon;
  const XChoice({super.key, required this.title, this.sub, required this.on, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Press(
      onTap: onTap,
      haptic: true,
      child: AnimatedContainer(
        duration: context.anim(XS.fast),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(XS.r3),
          border: Border.all(color: on ? c.ink : c.line, width: on ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? c.ink : c.gray2, width: on ? 6 : 1.5)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (icon != null) ...[Icon(icon, size: 16, color: c.ink), const SizedBox(width: 6)],
                Flexible(child: Text(title, style: XT.h3(context))),
              ]),
              if (sub != null) ...[const SizedBox(height: 3), Text(sub!, style: XT.small(context))],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Small text link button.
class XLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool underline;
  const XLink(this.text, {super.key, required this.onTap, this.underline = false});
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(text,
              style: XT.small(context, color: context.c.ink).copyWith(
                  fontWeight: FontWeight.w500, decoration: underline ? TextDecoration.underline : null)),
        ),
      );
}

/// Bottom dock that holds a page's main action.
class XDock extends StatelessWidget {
  final List<Widget> children;
  final bool row;
  const XDock({super.key, required this.children, this.row = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.fromLTRB(XS.gutter, 12, XS.gutter, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
      child: row
          ? Row(children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: children[i])],
            ])
          : Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
            ]),
    );
  }
}

/// Goal bar colours from the prototype: orange at 80 %+, faint under 25 %.
Color goalColor(BuildContext context, double pct) {
  final c = context.c;
  if (pct >= .8) return c.orange;
  if (pct < .25) return c.faint;
  return c.ink;
}

/// Scaffold with SafeArea and the app background.
class XScreen extends StatelessWidget {
  final Widget body;
  final Widget? dock;
  final Color? background;
  const XScreen({super.key, required this.body, this.dock, this.background});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: background ?? context.c.bg,
        body: SafeArea(bottom: dock == null, child: body),
        bottomNavigationBar: dock,
      );
}
