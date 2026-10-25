import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../people/follow_button.dart';
import 'comments_sheet.dart';
import 'share_sheet.dart';

/// Vertical reels viewer. Plays uploaded video; seeded reels without video show their poster.
class ReelsScreen extends StatefulWidget {
  final List<Json> reels;
  final int start;
  const ReelsScreen({super.key, required this.reels, this.start = 0});
  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late final PageController _page = PageController(initialPage: widget.start);
  late List<Json> reels = [...widget.reels];
  late int _i = widget.start;

  @override
  void initState() {
    super.initState();
    _view(_i);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _view(int i) {
    if (i < 0 || i >= reels.length) return;
    Api.i.post('reels/${reels[i].i('id')}/view/').catchError((_) => null);
  }

  Future<void> _like(int i) async {
    final r = reels[i];
    final was = r.b('liked');
    setState(() => reels[i] = {...r, 'liked': !was, 'likes': r.i('likes') + (was ? -1 : 1)});
    try {
      final res = await Api.i.post('reels/${r.i('id')}/like/') as Map;
      if (mounted) setState(() => reels[i] = {...reels[i], 'liked': res['liked'], 'likes': res['likes']});
    } catch (_) {}
  }

  Future<void> _save(int i) async {
    final res = await attempt(context, () => Api.i.post('reels/${reels[i].i('id')}/save/'));
    if (res != null && mounted) {
      setState(() => reels[i] = {...reels[i], 'saved': (res as Map)['saved']});
      context.say('${res['message']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 0),
            child: Row(children: [
              Expanded(child: Text('Reels', style: XT.h3(context, color: white).copyWith(fontSize: 17))),
              Text('${_i + 1} of ${reels.length}', style: XT.small(context, color: white.withValues(alpha: .72))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: white), tooltip: 'Close'),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _page,
              scrollDirection: Axis.vertical,
              itemCount: reels.length,
              onPageChanged: (i) {
                setState(() => _i = i);
                _view(i);
              },
              itemBuilder: (context, i) => _ReelPage(
                reel: reels[i],
                active: i == _i,
                onLike: () => _like(i),
                onSave: () => _save(i),
                onComments: () => showComments(context, 'reels/${reels[i].i('id')}',
                    onAdded: () => setState(() => reels[i] = {...reels[i], 'comments': reels[i].i('comments') + 1})),
                onShare: () => showShareSheet(context, kicker: 'REEL', title: reels[i].s('title'), sub: reels[i].m('author').s('name')),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ReelPage extends StatefulWidget {
  final Json reel;
  final bool active;
  final VoidCallback onLike, onSave, onComments, onShare;
  const _ReelPage({required this.reel, required this.active, required this.onLike, required this.onSave, required this.onComments, required this.onShare});
  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _v;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final url = widget.reel.s('video');
    if (url.isNotEmpty) {
      _v = VideoPlayerController.networkUrl(Uri.parse(url))
        ..setLooping(true)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          if (widget.active) _v!.play();
        }).catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
    }
  }

  @override
  void didUpdateWidget(_ReelPage old) {
    super.didUpdateWidget(old);
    final v = _v;
    if (v == null || !v.value.isInitialized) return;
    widget.active ? v.play() : v.pause();
  }

  @override
  void dispose() {
    _v?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    final dim = white.withValues(alpha: .72);
    final r = widget.reel;
    final v = _v;
    final a = r.m('author');
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: () {
            if (v == null || !v.value.isInitialized) return;
            setState(() => v.value.isPlaying ? v.pause() : v.play());
          },
          child: v != null && v.value.isInitialized
              ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: v.value.size.width, height: v.value.size.height, child: VideoPlayer(v)))
              : Center(
                  child: Text(_failed ? 'Video could not load' : (v == null ? 'VIDEO · ${r.s('duration')}' : 'Loading…'),
                      style: XT.label(context, color: white.withValues(alpha: .5))),
                ),
        ),
      ),
      if (v != null && v.value.isInitialized && !v.value.isPlaying)
        const Center(child: Icon(Icons.play_arrow_rounded, size: 72, color: Color(0xCCFFFFFF))),
      Positioned(
        right: 8,
        bottom: 20,
        child: Column(children: [
          _act(r.b('liked') ? Icons.favorite_rounded : Icons.favorite_border_rounded, fmtN(r.i('likes')), widget.onLike, color: r.b('liked') ? context.c.orange : white),
          _act(Icons.chat_bubble_outline_rounded, '${r.i('comments')}', widget.onComments),
          _act(Icons.send_outlined, 'Share', widget.onShare),
          _act(r.b('saved') ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, 'Save', widget.onSave),
        ]),
      ),
      Positioned(
        left: 16,
        right: 76,
        bottom: 24,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            XAvatar(a, size: 36, ink: true),
            const SizedBox(width: 10),
            Flexible(child: Text(a.s('name'), style: XT.h3(context, color: white).copyWith(fontSize: 14))),
            if (!r.b('mine')) ...[const SizedBox(width: 10), SizedBox(height: 32, child: FollowButton(user: a))],
          ]),
          gap8,
          Text(r.s('title'), style: XT.body(context, color: white)),
          gap4,
          Text('${r.s('plays')} plays', style: XT.small(context, color: dim)),
        ]),
      ),
    ]);
  }

  Widget _act(IconData i, String l, VoidCallback onTap, {Color color = const Color(0xFFFFFFFF)}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Semantics(
          button: true,
          label: l,
          child: Press(
            onTap: onTap,
            child: Column(children: [
              Icon(i, size: 28, color: color),
              const SizedBox(height: 3),
              Text(l, style: XT.small(context, color: const Color(0xFFFFFFFF)).copyWith(fontSize: 11)),
            ]),
          ),
        ),
      );
}
