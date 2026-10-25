import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/charts.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../clubs/club_screen.dart' show EventRow;
import '../people/follow_button.dart';
import '../routes.dart';
import 'comments_sheet.dart';
import 'reels_screen.dart';
import 'share_sheet.dart';

/// One feed item: activity, club event, reel, achievement or a user post.
class PostCard extends StatefulWidget {
  final Json post;
  final VoidCallback? onChanged;
  final List<Json>? reels; // for opening the reels viewer at this reel
  const PostCard(this.post, {super.key, this.onChanged, this.reels});
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Json p = widget.post;
  bool _hidden = false;

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    if (old.post != widget.post) p = widget.post;
  }

  bool get isReel => p.s('type') == 'reel';
  String get base => isReel ? 'reels/${p.i('id')}' : 'posts/${p.i('id')}';

  Future<void> _like() async {
    final was = p.b('liked');
    setState(() => p = {...p, 'liked': !was, 'likes': p.i('likes') + (was ? -1 : 1)});
    try {
      final r = await Api.i.post('$base/like/') as Map;
      if (mounted) setState(() => p = {...p, 'liked': r['liked'], 'likes': r['likes']});
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => p = {...p, 'liked': was, 'likes': p.i('likes') + (was ? 1 : -1)});
        context.say(e.message);
      }
    }
  }

  Future<void> _save() async {
    final r = await attempt(context, () => Api.i.post('$base/save/'));
    if (r != null && mounted) {
      setState(() => p = {...p, 'saved': (r as Map)['saved']});
      context.say('${r['message']}');
    }
  }

  void _menu() {
    final author = p.m('author');
    showXSheet(
      context,
      (ctx) => XSheetBody(children: [
        gap8,
        if (p.b('mine') && !isReel)
          XRow('Delete post', onTap: () async {
            Navigator.pop(ctx);
            final ok = await confirmX(context, title: 'Delete this post?', body: 'It is removed from every feed.', ok: 'Delete');
            if (!ok || !mounted) return;
            final r = await attempt(context, () => Api.i.delete('posts/${p.i('id')}/'));
            if (r != null && mounted) {
              setState(() => _hidden = true);
              context.say('Post deleted');
            }
          }),
        if (!p.b('mine') && !isReel)
          XRow('Not interested', sub: 'We will show you fewer posts like this', onTap: () async {
            Navigator.pop(ctx);
            final r = await attempt(context, () => Api.i.post('posts/${p.i('id')}/hide/'));
            if (r != null && mounted) {
              setState(() => _hidden = true);
              context.say('${(r as Map)['message']}');
            }
          }),
        if (!p.b('mine') && author.isNotEmpty)
          XRow('Mute ${author.s('name').split(' ').first}', sub: 'Hide their posts from your feed', onTap: () async {
            Navigator.pop(ctx);
            final r = await attempt(context, () => Api.i.post('users/${author.i('id')}/mute/'));
            if (r != null && mounted) {
              setState(() => _hidden = true);
              context.say('${(r as Map)['message']}');
            }
          }),
        if (!p.b('mine'))
          XRow('Report', sub: 'Our team reviews every report', onTap: () async {
            Navigator.pop(ctx);
            final r = await attempt(context, () => Api.i.post('report/', isReel ? {'reel_id': p.i('id')} : {'post_id': p.i('id')}));
            if (r != null && mounted) {
              setState(() => _hidden = true);
              context.say('${(r as Map)['message']}');
            }
          }),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final c = context.c;
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ..._content(),
        _actions(),
      ]),
    );
  }

  Widget _pad(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: XS.gutter), child: w);

  Widget _head({required String sub, Widget? trailing}) {
    final a = p.m('author');
    return _pad(Row(children: [
      Press(onTap: () => Go.person(context, a.i('id')), child: XAvatar(a, size: 40)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Press(onTap: () => Go.person(context, a.i('id')), child: Text(a.s('name'), style: XT.h3(context).copyWith(fontSize: 15))),
          Text(sub, style: XT.small(context)),
        ]),
      ),
      trailing ?? XIconBtn(Icons.more_horiz_rounded, tooltip: 'More', onTap: _menu),
    ]));
  }

  List<Widget> _content() {
    final c = context.c;
    switch (p.s('kind')) {
      case 'reel':
        final a = p.m('author');
        return [
          _head(sub: 'Reel · ${p.s('time')}', trailing: p.b('mine') ? null : FollowButton(user: a)),
          gap12,
          Press(
            onTap: () => context.push(ReelsScreen(reels: widget.reels ?? [p], start: (widget.reels ?? [p]).indexWhere((r) => r.i('id') == p.i('id')).clamp(0, 99))),
            child: ReelPoster(p, height: 420),
          ),
        ];
      case 'activity':
        final pts = RouteMap.parse(p.m('activity')['points']);
        return [
          _head(sub: p.s('sub', 'Activity · ${p.s('time')}')),
          gap12,
          _pad(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.s('title'), style: XT.h3(context)),
            gap12,
            _stats(p['stats']),
          ])),
          if (pts.length > 2) ...[
            gap12,
            Press(
              onTap: () => Go.activity(context, p.m('activity').i('id')),
              child: RouteMap(points: pts, height: 190, seed: p.i('id')),
            ),
          ],
          if (p.s('body').isNotEmpty) ...[gap12, _pad(Text(p.s('body'), style: XT.body(context)))],
        ];
      case 'club':
        final cl = p.m('club');
        final e = p.m('event');
        return [
          _pad(Row(children: [
            Press(onTap: () => Go.club(context, cl.i('id')), child: XAvatar({'initial': cl.s('initial'), 'name': cl.s('name')}, size: 40, square: true, ink: true)),
            const SizedBox(width: 12),
            Expanded(
              child: Press(
                onTap: () => Go.club(context, cl.i('id')),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cl.s('name'), style: XT.h3(context).copyWith(fontSize: 15)),
                  Text(p.s('club_meta'), style: XT.small(context)),
                ]),
              ),
            ),
            XButton(p.b('club_joined') ? 'Joined' : 'View', small: true, expand: false, kind: p.b('club_joined') ? XBtn.secondary : XBtn.primary,
                onTap: () => Go.club(context, cl.i('id'))),
          ])),
          if (p.s('body').isNotEmpty) ...[gap12, _pad(Text(p.s('body'), style: XT.body(context)))],
          if (e.isNotEmpty) ...[
            gap12,
            _pad(XCard(
              muted: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                XKicker('Event · ${e.s('mon')} ${e.s('day')}', color: c.ink),
                gap8,
                Text(e.s('title'), style: XT.h3(context)),
                gap8,
                Row(children: [Icon(Icons.schedule_rounded, size: 16, color: c.muted), const SizedBox(width: 8), Expanded(child: Text(e.s('time'), style: XT.small(context)))]),
                if (e.s('place').isNotEmpty) ...[
                  gap4,
                  Row(children: [Icon(Icons.place_outlined, size: 16, color: c.muted), const SizedBox(width: 8), Expanded(child: Text(e.s('place'), style: XT.small(context)))]),
                ],
                EventRow(e),
              ]),
            )),
          ],
        ];
      case 'achievement':
        final a = p.m('author');
        final b = p.m('badge');
        return [
          _pad(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            a.isEmpty
                ? XAvatar({'initial': p.m('club').s('initial')}, size: 40, square: true, ink: true)
                : Press(onTap: () => Go.person(context, a.i('id')), child: XAvatar(a, size: 40)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: a.isEmpty ? p.m('club').s('name') : a.s('name'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' ${p.s('body')}'),
                ]), style: XT.body(context)),
                gap8,
                XCard(
                  muted: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    const Icon(Icons.emoji_events_outlined, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b.s('title'), style: XT.h3(context).copyWith(fontSize: 14)),
                        Text(b.s('sub'), style: XT.small(context).copyWith(fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
                gap8,
                Text(p.s('time'), style: XT.small(context)),
              ]),
            ),
            XIconBtn(Icons.more_horiz_rounded, tooltip: 'More', onTap: _menu),
          ])),
        ];
      default:
        return [
          _head(sub: '${p.m('club').isNotEmpty ? 'in ${p.m('club').s('name')}' : p.s('audience')} · ${p.s('time')}'),
          if (p.s('body').isNotEmpty) ...[gap12, _pad(Text(p.s('body'), style: XT.body(context)))],
          if (p.s('photo').isNotEmpty) ...[
            gap12,
            Image.network(p.s('photo'), height: 280, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 220, color: c.gray, child: Icon(Icons.image_outlined, color: c.muted))),
          ],
          for (final at in p.l('attachments')) ...[
            gap12,
            _pad(XCard(
              muted: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(at.s('kind') == 'activity' ? Icons.monitor_heart_outlined : at.s('kind') == 'challenge' ? Icons.flag_outlined : Icons.emoji_events_outlined, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    XLabel(at.s('label')),
                    gap4,
                    Text(at.s('value'), style: XT.h3(context).copyWith(fontSize: 14)),
                  ]),
                ),
              ]),
            )),
          ],
          if ((p['stats'] as List? ?? const []).isNotEmpty) ...[
            gap12,
            _pad(XCard(muted: true, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: _stats(p['stats']))),
          ],
        ];
    }
  }

  Widget _stats(dynamic raw) {
    final stats = [for (final s in (raw as List? ?? const [])) s as List];
    return Row(children: [
      for (final s in stats.take(3)) Expanded(child: XStat('${s[0]}', '${s[1]}', size: 18)),
    ]);
  }

  Widget _actions() {
    final c = context.c;
    final liked = p.b('liked');
    final n = p.i('comments');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Semantics(
            toggled: liked,
            label: 'Like',
            child: XIconBtn(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: liked ? c.orange : null, onTap: _like),
          ),
          XIconBtn(Icons.chat_bubble_outline_rounded, tooltip: 'Comments', onTap: () => showComments(context, base, onAdded: () => setState(() => p = {...p, 'comments': p.i('comments') + 1}))),
          XIconBtn(Icons.send_outlined, tooltip: 'Share', onTap: () => showShareSheet(context,
              kicker: isReel ? 'REEL' : p.s('kind').toUpperCase(), title: p.s('title', p.m('badge').s('title', p.m('author').s('name'))), sub: p.s('body'))),
          const Spacer(),
          Semantics(
            toggled: p.b('saved'),
            label: 'Save',
            child: XIconBtn(p.b('saved') ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, onTap: _save),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Press(
            onTap: () => showComments(context, base, onAdded: () => setState(() => p = {...p, 'comments': p.i('comments') + 1})),
            child: Text('${fmtN(p.i('likes'))} ${p.s('like_word', 'likes')}${n > 0 ? ' · View $n comment${n > 1 ? 's' : ''}' : ' · Add a comment'}',
                style: XT.small(context, color: c.ink)),
          ),
        ),
      ]),
    );
  }
}

/// Black reel poster with the title and play button (used in feed and grids).
class ReelPoster extends StatelessWidget {
  final Json r;
  final double height;
  final bool compact;
  const ReelPoster(this.r, {super.key, this.height = 420, this.compact = false});
  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    final dim = white.withValues(alpha: .72);
    return Container(
      height: height,
      color: const Color(0xFF000000),
      padding: EdgeInsets.all(compact ? 12 : 20),
      child: Stack(children: [
        if (!compact) Align(alignment: Alignment.topLeft, child: Text(r.s('tag').toUpperCase(), style: XT.label(context, color: dim))),
        Align(
          alignment: compact ? Alignment.topRight : Alignment.center,
          child: Container(
            width: compact ? 32 : 64,
            height: compact ? 32 : 64,
            decoration: BoxDecoration(color: white.withValues(alpha: .16), shape: BoxShape.circle),
            child: Icon(Icons.play_arrow_rounded, color: white, size: compact ? 20 : 30),
          ),
        ),
        Align(
          alignment: compact ? Alignment.bottomLeft : Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(top: compact ? 0 : 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.s('title'), maxLines: compact ? 4 : 3, overflow: TextOverflow.ellipsis,
                  style: XT.h2(context, color: white).copyWith(fontSize: compact ? 15 : 28, height: 1.1)),
              if (compact) ...[const SizedBox(height: 6), Text('${r.m('author').s('name')} · ${r.s('plays')}', style: XT.small(context, color: dim).copyWith(fontSize: 12))],
            ]),
          ),
        ),
        if (!compact)
          Align(
            alignment: Alignment.bottomLeft,
            child: Text('${r.s('duration')}   ${r.s('plays')} plays', style: XT.small(context, color: dim)),
          ),
      ]),
    );
  }
}
