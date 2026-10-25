import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';
import '../social/post_card.dart';
import '../social/share_sheet.dart';
import 'clubs_screen.dart';

/// A club or space page: posts, events, members, weekly board.
class ClubScreen extends StatefulWidget {
  final int id;
  final String tab;
  const ClubScreen({super.key, required this.id, this.tab = 'posts'});
  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  late String _tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      body: Loader<Json>(
        key: ValueKey(_tab),
        load: () async => Map<String, dynamic>.from(await Api.i.get('clubs/${widget.id}/?tab=$_tab') as Map),
        builder: (context, d, reload) {
          final tabs = [for (final t in (d['tabs'] as List)) [for (final x in t as List) '$x']];
          return ListView(padding: EdgeInsets.zero, children: [
            _hero(d),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Transform.translate(
                  offset: const Offset(0, -38),
                  child: Container(
                    width: 76,
                    height: 76,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
                    child: Text(d.s('initial'), style: XT.h2(context)),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.s('name'), style: XT.h1(context)),
                    gap8,
                    Row(children: [
                      Icon(d.b('is_private') ? Icons.lock_outline_rounded : Icons.public_rounded, size: 14, color: c.muted),
                      const SizedBox(width: 6),
                      Flexible(child: Text('${d.s('type')} · ${d.b('is_private') ? 'Private' : 'Public'} · ${d.s('city')}', style: XT.small(context))),
                    ]),
                    gap8,
                    Text('${d.s('description')}${d.s('admin').isNotEmpty ? ' Run by ${d.s('admin')}.' : ''}', style: XT.body(context)),
                    gap16,
                    Row(children: [
                      Expanded(child: XStat('Members', fmtN(d.i('members')), size: 19)),
                      Expanded(child: XStat('This week', d.s('week'), size: 19)),
                      Expanded(child: XStat('Events', '${d.i('events')}', size: 19)),
                    ]),
                    gap16,
                    _actions(d),
                    gap16,
                    Container(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                        for (final t in tabs)
                          Padding(
                            padding: const EdgeInsets.only(right: 22),
                            child: Press(
                              onTap: () => setState(() => _tab = t[0]),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _tab == t[0] ? c.ink : Colors.transparent, width: 2))),
                                child: Text(t[1], style: XT.h3(context, color: _tab == t[0] ? c.ink : c.muted).copyWith(fontSize: 14)),
                              ),
                            ),
                          ),
                      ]),
                      ),
                    ),
                    gap16,
                    ..._body(d, reload),
                  ]),
                ),
              ]),
            ),
            if (_tab == 'posts' && !d.has('locked')) ...[for (final p in d.l('posts')) PostCard(p, onChanged: reload)],
            const SizedBox(height: 32),
          ]);
        },
      ),
    );
  }

  Widget _hero(Json d) {
    final top = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 170 + top,
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _HeroPainter(context.c.orange))),
        Positioned(
          top: top + 4,
          left: 4,
          right: 4,
          child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFFFFFFFF)), tooltip: 'Back'),
            const Spacer(),
            IconButton(
                onPressed: () => showShareSheet(context, kicker: 'CLUB', title: d.s('name'), sub: d.s('description'), label: 'this club'),
                icon: const Icon(Icons.send_outlined, color: Color(0xFFFFFFFF)),
                tooltip: 'Share club'),
          ]),
        ),
      ]),
    );
  }

  Widget _actions(Json d) {
    if (d.b('is_admin')) {
      return Row(children: [
        Expanded(child: XButton('Post to club', onTap: () => Go.compose(context, 'post', clubId: widget.id))),
        const SizedBox(width: 8),
        Expanded(child: XButton(d.b('is_space') ? 'Members' : 'New event', kind: XBtn.secondary,
            onTap: () => d.b('is_space') ? setState(() => _tab = 'members') : Go.compose(context, 'event', clubId: widget.id))),
      ]);
    }
    return Row(children: [
      Expanded(child: JoinButton(d, full: true, joinLabel: d.b('is_space') ? 'Join space' : 'Join')),
      const SizedBox(width: 8),
      Expanded(
        child: XButton(d.b('is_space') ? 'Start a conversation' : 'Message', small: true, kind: XBtn.secondary, onTap: () async {
          if (d.b('is_space')) {
            if (!d.b('joined')) return context.say('Join this space before posting');
            return Go.compose(context, 'post', clubId: widget.id);
          }
          final r = await attempt(context, () => Api.i.post('clubs/${widget.id}/chat/'));
          if (r != null && mounted) Go.thread(context, (r as Map)['thread_id'] as int);
        }),
      ),
    ]);
  }

  List<Widget> _body(Json d, Future<void> Function() reload) {
    final c = context.c;
    if (d.has('locked')) return [XNote(text: d.s('locked'))];
    switch (_tab) {
      case 'events':
        final ev = d.l('events_list');
        if (ev.isEmpty) return [Text('No events yet.', style: XT.small(context))];
        return [for (final e in ev) EventRow(e)];
      case 'members':
        return [
          Text('${fmtN(d.i('members'))} members', style: XT.small(context)),
          gap12,
          if (d.l('requests').isNotEmpty) ...[
            const XLabel('Want to join'),
            for (final p in d.l('requests'))
              XRow(p.s('name'), leading: XAvatar(p, size: 40), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                XButton('Approve', small: true, expand: false, onTap: () async {
                  final r = await attempt(context, () => Api.i.post('clubs/${widget.id}/requests/${p.i('id')}/', {'accept': true}));
                  if (r != null && mounted) {
                    context.say('${(r as Map)['message']}');
                    reload();
                  }
                }),
                const SizedBox(width: 6),
                XButton('Decline', small: true, expand: false, kind: XBtn.secondary, onTap: () async {
                  final r = await attempt(context, () => Api.i.post('clubs/${widget.id}/requests/${p.i('id')}/', {'accept': false}));
                  if (r != null && mounted) reload();
                }),
              ])),
            gap16,
          ],
          XGrid(cols: 5, gap: 10, children: [
            for (final p in d.l('member_list'))
              Press(
                onTap: () => Go.person(context, p.i('id')),
                child: Column(children: [
                  XAvatar(p, size: 52),
                  const SizedBox(height: 6),
                  Text(p.s('name').split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.small(context, color: c.ink).copyWith(fontSize: 11)),
                ]),
              ),
          ]),
        ];
      case 'board':
        final b = d.m('board');
        Widget row(Json r) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: r.b('me') ? c.gray : null, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                SizedBox(width: 22, child: Text('${r.i('rank')}', style: XT.h3(context).copyWith(fontSize: 15))),
                XAvatar({'initial': r.s('initial'), 'name': r.s('name')}, size: 36, ink: r.i('rank') == 1),
                const SizedBox(width: 12),
                Expanded(child: Text(r.s('name'), style: XT.h3(context).copyWith(fontSize: 15))),
                Text(r.s('label'), style: XT.h3(context).copyWith(fontSize: 15)),
              ]),
            );
        return [
          Row(children: [const Expanded(child: XLabel('This week')), Text('Resets Monday', style: XT.small(context))]),
          gap8,
          if (b.l('top').isEmpty) Text('No tracked sessions from members yet this week.', style: XT.small(context)),
          for (final r in b.l('top')) row(r),
          if (b.m('me').isNotEmpty) row(b.m('me')),
          if (b.s('note').isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: Text(b.s('note'), style: XT.small(context))),
        ];
      case 'about':
        return [
          Text(d.s('description'), style: XT.body(context)),
          gap16,
          XNote(label: 'Community rules', text: d.s('rules')),
          gap12,
          Text('Moderated by ${d.s('admin')}. Weekly check-in every Monday.', style: XT.small(context)),
        ];
      default:
        final pin = d.m('pinned');
        final posts = d.l('posts');
        return [
          if (pin.isNotEmpty)
            XNote(
              label: pin.s('kicker'),
              dot: true,
              text: '',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pin.s('text'), style: XT.body(context)),
                gap8,
                Text(pin.s('sub'), style: XT.small(context)),
              ]),
            ),
          gap12,
          if (posts.isEmpty) Text(d.b('is_space') && !d.b('joined') ? 'Join this space to post and take part in discussions.' : 'No posts yet.', style: XT.small(context)),
        ];
    }
  }
}

/// Event row: date block, title, time · place · going, Join/Going.
class EventRow extends StatefulWidget {
  final Json e;
  const EventRow(this.e, {super.key});
  @override
  State<EventRow> createState() => _EventRowState();
}

class _EventRowState extends State<EventRow> {
  late Json e = widget.e;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XRow(
      e.s('title'),
      sub: '${e.s('meta')} · ${e.i('going_count')} going',
      leading: Container(
        width: 52,
        height: 56,
        decoration: BoxDecoration(color: c.gray, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(e.s('mon').toUpperCase(), style: XT.label(context).copyWith(fontSize: 10)),
          const SizedBox(height: 4),
          Text(e.s('day'), style: XT.metric(context, 20)),
        ]),
      ),
      trailing: XButton(e.b('going') ? 'Going' : 'Join', small: true, expand: false, kind: e.b('going') ? XBtn.secondary : XBtn.primary, onTap: () async {
        final r = await attempt(context, () => Api.i.post('events/${e.i('id')}/going/'));
        if (r != null && mounted) {
          setState(() => e = Map<String, dynamic>.from((r as Map)['event'] as Map));
          context.say('${r['message']}');
          context.app.changed();
        }
      }),
    );
  }
}

class _HeroPainter extends CustomPainter {
  final Color accent;
  _HeroPainter(this.accent);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF000000));
    final a = Path()
      ..moveTo(-10, s.height * .76)
      ..cubicTo(s.width * .15, s.height * .53, s.width * .28, s.height * .82, s.width * .44, s.height * .59)
      ..cubicTo(s.width * .6, s.height * .35, s.width * .72, s.height * .18, s.width + 10, s.height * .41);
    canvas.drawPath(a, Paint()
      ..color = const Color(0xFF272727)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14);
    final b = Path()
      ..moveTo(s.width * .1, s.height * .82)
      ..cubicTo(s.width * .26, s.height * .65, s.width * .36, s.height * .76, s.width * .49, s.height * .6)
      ..cubicTo(s.width * .62, s.height * .44, s.width * .72, s.height * .29, s.width * .85, s.height * .38);
    canvas.drawPath(b, Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_HeroPainter o) => false;
}
