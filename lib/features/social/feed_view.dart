import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../clubs/clubs_screen.dart' show JoinButton;
import '../people/find_friends_screen.dart';
import '../people/follow_button.dart';
import '../routes.dart';
import '../shell/shell.dart';
import 'post_card.dart';
import 'reels_screen.dart';

/// Home → Social: Posts · Reels · Spaces.
class FeedView extends StatefulWidget {
  const FeedView({super.key});
  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  int _seg = 0;
  String _filter = 'foryou';
  static const _filters = [('foryou', 'For you'), ('following', 'Following'), ('clubs', 'Clubs'), ('reels', 'Reels'), ('nearby', 'Nearby')];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(XS.gutter, 16, XS.gutter, 0),
        child: XSegment(labels: const ['Posts', 'Reels', 'Spaces'], index: _seg, onPick: (i) => setState(() => _seg = i)),
      ),
      Expanded(child: switch (_seg) { 0 => _posts(), 1 => _reels(), _ => _spaces() }),
    ]);
  }

  Widget _posts() {
    return Loader<Json>(
      key: ValueKey(_filter),
      load: () async => Map<String, dynamic>.from(await Api.i.get('feed/?filter=$_filter') as Map),
      builder: (context, d, reload) {
        final items = d.l('items');
        final reels = items.where((i) => i.s('type') == 'reel').toList();
        final rows = <Widget>[
          _composeRow(),
          if (d.l('live').isNotEmpty) _live(d.l('live')),
          _week(d.l('week')),
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: XS.gutter), children: [
              for (final f in _filters) ...[XChip(f.$2, on: _filter == f.$1, onTap: () => setState(() => _filter = f.$1)), const SizedBox(width: 8)],
            ]),
          ),
          gap16,
        ];
        if (items.isEmpty) {
          rows.add(XEmpty(
            icon: _filter == 'clubs' ? Icons.groups_outlined : Icons.people_outline_rounded,
            title: 'Nothing here yet',
            body: _filter == 'following' ? 'Follow people to see their training here.' : _filter == 'clubs' ? 'Join a club to see its posts and events.' : 'Check back soon.',
            action: _filter == 'clubs' ? 'Browse clubs' : 'Find friends',
            onAction: () => _filter == 'clubs' ? ShellNav.go(context, 2) : context.push(const FindFriendsScreen()),
          ));
        }
        for (var i = 0; i < items.length; i++) {
          rows.add(PostCard(items[i], onChanged: reload, reels: reels));
          if (i == 1 && _filter == 'foryou' && d.l('clubs').isNotEmpty) rows.add(_clubs(d.l('clubs')));
          if (i == 3 && _filter == 'foryou' && d.l('friends').isNotEmpty) rows.add(_friends(d.l('friends')));
        }
        rows.add(const SizedBox(height: 32));
        return ListView(padding: EdgeInsets.zero, children: rows);
      },
    );
  }

  Widget _composeRow() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(XS.gutter, 16, XS.gutter, 12),
      child: Row(children: [
        XAvatar(context.appWatch.me, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Press(
            onTap: () => Go.compose(context, 'post'),
            child: Container(
              height: 44,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: c.gray, borderRadius: BorderRadius.circular(12)),
              child: Text('Share a workout, meal or win', style: XT.small(context)),
            ),
          ),
        ),
        XIconBtn(Icons.videocam_outlined, tooltip: 'Record a reel', onTap: () => Go.compose(context, 'reel')),
      ]),
    );
  }

  Widget _live(List<Json> live) => Padding(
        padding: const EdgeInsets.fromLTRB(XS.gutter, 0, XS.gutter, 12),
        child: XCard(
          muted: true,
          child: Row(children: [
            const XDot(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  live.length == 1
                      ? '${live.first.s('name')} is out on a ${live.first.s('sport').toLowerCase()} right now'
                      : '${live.first.s('name')} and ${live.length - 1} other${live.length > 2 ? 's' : ''} are out training right now',
                  style: XT.small(context, color: context.c.ink)),
            ),
          ]),
        ),
      );

  Widget _week(List<Json> cards) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
          child: Row(children: [const Expanded(child: XLabel('Your week')), XLink('See all', onTap: () => ShellNav.go(context, 3))]),
        ),
        gap8,
        SizedBox(
          height: 112,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: XS.gutter), children: [
            for (final w in cards) ...[
              SizedBox(
                width: 150,
                child: XCard(
                  dark: w.b('ink'),
                  muted: !w.b('ink'),
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    w.b('ink') ? XKicker(w.s('label'), color: c.onInk.withValues(alpha: .7)) : XLabel(w.s('label')),
                    gap8,
                    FittedBox(child: Text(w.s('value'), style: XT.metric(context, 26, color: w.b('ink') ? c.onInk : null))),
                    gap4,
                    Text(w.s('sub'), maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.small(context, color: w.b('ink') ? c.onInk.withValues(alpha: .7) : null)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _clubs(List<Json> clubs) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: XS.gutter),
          child: Row(children: [const Expanded(child: XLabel('Clubs and crews near you')), XLink('Browse', onTap: () => ShellNav.go(context, 2))]),
        ),
        gap12,
        SizedBox(
          height: 186,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: XS.gutter), children: [
            for (final cl in clubs) ...[
              SizedBox(
                width: 164,
                child: XCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Press(
                      onTap: () => Go.club(context, cl.i('id')),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        XAvatar({'initial': cl.s('initial'), 'name': cl.s('name')}, size: 44, square: true, ink: cl.s('type') == 'Gym' || cl.s('type') == 'Cycling'),
                        gap8,
                        Text(cl.s('name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: XT.h3(context).copyWith(fontSize: 14, height: 1.3)),
                        Text('${cl.s('type')} · ${fmtN(cl.i('members'))}', style: XT.small(context).copyWith(fontSize: 12)),
                      ]),
                    ),
                    const Spacer(),
                    JoinButton(cl, full: true),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _friends(List<Json> people) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(XS.gutter, 20, XS.gutter, 20),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: XLabel('Find friends')), XLink('See all', onTap: () => context.push(const FindFriendsScreen()))]),
        for (final p in people) PersonRow(p),
      ]),
    );
  }

  Widget _reels() {
    return Loader<Json>(
      load: () async => Map<String, dynamic>.from(await Api.i.get('reels/') as Map),
      builder: (context, d, reload) {
        final items = d.l('items');
        return ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 16, XS.gutter, 32), children: [
          Align(
            alignment: Alignment.centerLeft,
            child: XButton('Record a reel', icon: Icons.videocam_outlined, small: true, expand: false, kind: XBtn.secondary, onTap: () => Go.compose(context, 'reel')),
          ),
          gap12,
          if (items.isEmpty) const XEmpty(icon: Icons.play_circle_outline_rounded, title: 'No reels yet', body: 'Record one to get started.'),
          XGrid(cols: 2, children: [
            for (var k = 0; k < items.length; k++)
              Press(
                onTap: () => context.push(ReelsScreen(reels: items, start: k)),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: ReelPoster(items[k], height: 240, compact: true)),
              ),
          ]),
        ]);
      },
    );
  }

  Widget _spaces() {
    return Loader<Json>(
      load: () async => Map<String, dynamic>.from(await Api.i.get('spaces/') as Map),
      builder: (context, d, reload) => ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 16, XS.gutter, 32), children: [
        const XLabel('Find your people'),
        gap8,
        Text('Progress is better together.', style: XT.h2(context)),
        gap4,
        Text('Join a space for shared goals, advice and accountability, or a club for real-world runs, rides and games.', style: XT.small(context)),
        gap12,
        Row(children: [
          XButton('Explore posts', small: true, expand: false, kind: XBtn.secondary, onTap: () => setState(() => _seg = 0)),
          const SizedBox(width: 8),
          XButton('Clubs near you', small: true, expand: false, kind: XBtn.secondary, onTap: () => ShellNav.go(context, 2)),
        ]),
        gap16,
        Row(children: [const Expanded(child: XLabel('Suggested spaces')), Text('${d.l('items').length} spaces', style: XT.small(context))]),
        gap12,
        for (final s in d.l('items')) ...[
          XCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                XAvatar({'initial': s.s('initial'), 'name': s.s('name')}, size: 48, square: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    XLabel(s.s('type')),
                    gap4,
                    Text(s.s('name'), style: XT.h3(context)),
                    Text('${fmtN(s.i('members'))} members · ${s.s('week')}', style: XT.small(context)),
                  ]),
                ),
              ]),
              gap8,
              Text(s.s('description'), style: XT.small(context, color: context.c.ink)),
              gap12,
              Row(children: [
                JoinButton(s, joinLabel: 'Join space'),
                const SizedBox(width: 8),
                XButton('View feed', small: true, expand: false, kind: XBtn.secondary, onTap: () => Go.club(context, s.i('id'))),
              ]),
            ]),
          ),
          gap12,
        ],
        XNote(label: 'Community rules', text: d.s('rules')),
      ]),
    );
  }
}
