import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// Story bubbles under the Home top bar. Orange ring = not seen yet.
class StoriesRow extends StatefulWidget {
  const StoriesRow({super.key});
  @override
  State<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<StoriesRow> {
  Json? _d;
  int _seen = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final v = context.appWatch.version;
    if (v != _seen) {
      _seen = v;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('stories/');
      if (mounted) setState(() => _d = Map<String, dynamic>.from(r as Map));
    } catch (_) {}
  }

  Future<void> _open(List<Json> groups, int i) async {
    await Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => StoryViewer(groups: groups, start: i),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.c;
    if (d == null) return const SizedBox(height: 104);
    final mine = d.m('mine');
    final items = d.l('items');
    final all = [if (mine.isNotEmpty) mine, ...items];
    return SizedBox(
      height: 104,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(XS.gutter, 10, XS.gutter, 6), children: [
        _bubble(
          label: 'Your story',
          initial: d.s('initial', '?'),
          ring: mine.isNotEmpty && !mine.b('seen') ? c.orange : (mine.isNotEmpty ? c.gray2 : c.surface),
          plus: mine.isEmpty,
          onTap: () => mine.isEmpty ? Go.compose(context, 'story') : _open(all, 0),
        ),
        for (var i = 0; i < items.length; i++)
          _bubble(
            label: items[i].s('who'),
            initial: items[i].s('initial'),
            ring: items[i].b('seen') ? c.gray2 : c.orange,
            club: items[i].b('club'),
            onTap: () => _open(all, mine.isEmpty ? i : i + 1),
          ),
      ]),
    );
  }

  Widget _bubble({required String label, required String initial, required Color ring, bool plus = false, bool club = false, required VoidCallback onTap}) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Semantics(
        button: true,
        label: '$label story',
        child: Press(
          onTap: onTap,
          child: SizedBox(
            width: 66,
            child: Column(children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ring, border: ring == c.surface ? Border.all(color: c.line) : null),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.bg),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: club ? c.ink : c.gray),
                      child: Text(initial, style: XT.h3(context, color: club ? c.onInk : c.ink).copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                if (plus)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 2)),
                      child: Icon(Icons.add_rounded, size: 13, color: c.onInk),
                    ),
                  ),
              ]),
              const SizedBox(height: 5),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.small(context, color: c.ink).copyWith(fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Full-screen stories: auto-advance, tap left/right, reply, like.
class StoryViewer extends StatefulWidget {
  final List<Json> groups;
  final int start;
  const StoryViewer({super.key, required this.groups, required this.start});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late int g = widget.start;
  int st = 0, sl = 0; // story, slide
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  final _reply = TextEditingController();

  Json get group => widget.groups[g];
  List<Json> get stories => group.l('stories');
  List<Json> get slides => stories[st].l('slides');

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void dispose() {
    _a.dispose();
    _reply.dispose();
    super.dispose();
  }

  void _show() {
    _a.forward(from: 0);
    final id = stories[st].i('id');
    Api.i.post('stories/$id/view/').catchError((_) => null);
  }

  void _next() {
    if (sl < slides.length - 1) {
      setState(() => sl++);
    } else if (st < stories.length - 1) {
      setState(() {
        st++;
        sl = 0;
      });
    } else if (g < widget.groups.length - 1) {
      setState(() {
        g++;
        st = 0;
        sl = 0;
      });
    } else {
      Navigator.pop(context);
      return;
    }
    _show();
  }

  void _prev() {
    if (sl > 0) {
      setState(() => sl--);
    } else if (st > 0) {
      setState(() {
        st--;
        sl = 0;
      });
    } else if (g > 0) {
      setState(() {
        g--;
        st = 0;
        sl = 0;
      });
    }
    _show();
  }

  Future<void> _sendReply() async {
    final t = _reply.text.trim();
    if (t.isEmpty) return;
    _reply.clear();
    FocusScope.of(context).unfocus();
    final r = await attempt(context, () => Api.i.post('stories/${stories[st].i('id')}/reply/', {'text': t}));
    if (r != null && mounted) context.say('${(r as Map)['message']}');
    _a.forward();
  }

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    final dim = white.withValues(alpha: .72);
    final s = slides[sl];
    final total = slides.length;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              for (var k = 0; k < total; k++)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: white.withValues(alpha: .3), borderRadius: BorderRadius.circular(2)),
                    child: k < sl
                        ? Container(color: white)
                        : k == sl
                            ? AnimatedBuilder(
                                animation: _a,
                                builder: (_, __) => FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _a.value, child: Container(color: white)))
                            : null,
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
            child: Row(children: [
              XAvatar({'initial': group.s('initial'), 'name': group.s('who')}, size: 36, ink: true),
              const SizedBox(width: 10),
              Expanded(child: Text('${group.s('who')} · ${stories[st].s('time')}', style: XT.h3(context, color: white).copyWith(fontSize: 14))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: white), tooltip: 'Close story'),
            ]),
          ),
          Expanded(
            child: GestureDetector(
              onLongPressStart: (_) => _a.stop(),
              onLongPressEnd: (_) => _a.forward(),
              child: Stack(children: [
                if (s.s('photo').isNotEmpty) Positioned.fill(child: Image.network(s.s('photo'), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                if (s.s('photo').isNotEmpty) Positioned.fill(child: Container(color: const Color(0x66000000))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    XKicker(s.s('kicker'), color: dim),
                    gap16,
                    Text(s.s('big'), style: XT.big(context, color: white, size: 52)),
                    gap16,
                    Text(s.s('text'), style: XT.body(context, color: dim)),
                  ]),
                ),
                Row(children: [
                  Expanded(flex: 35, child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _prev, child: Semantics(label: 'Previous', button: true, child: const SizedBox.expand()))),
                  Expanded(flex: 65, child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _next, child: Semantics(label: 'Next', button: true, child: const SizedBox.expand()))),
                ]),
              ]),
            ),
          ),
          if (!group.b('mine'))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 20),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _reply,
                    onTap: () => _a.stop(),
                    onSubmitted: (_) => _sendReply(),
                    style: XT.body(context, color: white).copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: group.b('club') ? 'Reply in the club chat' : 'Reply to ${group.s('who')}',
                      hintStyle: XT.small(context, color: dim),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF333333))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF666666))),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await Api.i.post('stories/${stories[st].i('id')}/like/').catchError((_) => null);
                    if (mounted) context.say('Liked');
                  },
                  icon: const Icon(Icons.favorite_border_rounded, color: white),
                  tooltip: 'Like story',
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
