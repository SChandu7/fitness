import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../notifications/notifications_screen.dart';
import '../routes.dart';

/// Inbox: nudges shortcut + every conversation (direct, club, challenge).
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _q = '';
  Timer? _debounce;
  final _search = TextEditingController();
  final _list = GlobalKey<LoaderState<Json>>();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _newMessage() async {
    final id = await showXSheet<int>(context, (ctx) => const _NewMessageSheet());
    if (id != null && mounted) {
      await Go.thread(context, id);
      _list.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Column(children: [
        XTopBar('Messages', actions: [XIconBtn(Icons.edit_outlined, tooltip: 'New message', onTap: _newMessage)]),
        Padding(
          padding: const EdgeInsets.fromLTRB(XS.gutter, 4, XS.gutter, 8),
          child: XField(
            controller: _search,
            hint: 'Search',
            prefix: Icon(Icons.search_rounded, size: 20, color: c.muted),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _q = v.trim()));
            },
          ),
        ),
        Expanded(
          child: Loader<Json>(
            key: _list,
            load: () async => Map<String, dynamic>.from(await Api.i.get('threads/?q=${Uri.encodeComponent(_q)}') as Map),
            builder: (context, d, reload) => ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 0, XS.gutter, 32), children: [
                XRow(
                  'Nudges',
                  sub: 'Water, protein and streak reminders',
                  leading: _circle(context, Icons.notifications_none_rounded),
                  trailing: d.i('nudges') > 0 ? _badge(context, d.i('nudges')) : null,
                  chevron: true,
                  onTap: () async {
                    await context.push(const NotificationsScreen());
                    reload();
                  },
                ),
                const Padding(padding: EdgeInsets.fromLTRB(0, 14, 0, 2), child: XLabel('Conversations')),
                if (d.l('items').isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(_q.isEmpty ? 'No conversations yet. Tap the pencil to message a friend.' : 'No conversations match.', style: XT.small(context)),
                  ),
                for (final t in d.l('items')) _ThreadRow(t, onOpen: () async {
                  await Go.thread(context, t.i('id'));
                  reload();
                  if (context.mounted) context.app.changed();
                }),
              ]),
          ),
        ),
      ]),
    );
  }

  static Widget _circle(BuildContext context, IconData i) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: context.c.gray, shape: BoxShape.circle),
        child: Icon(i, size: 22, color: context.c.ink),
      );
}

Widget _badge(BuildContext context, int n) => Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: context.c.orange, borderRadius: BorderRadius.circular(10)),
      child: Text('$n', style: XT.label(context, color: const Color(0xFF000000)).copyWith(fontSize: 11, letterSpacing: 0)),
    );

class _ThreadRow extends StatelessWidget {
  final Json t;
  final VoidCallback onOpen;
  const _ThreadRow(this.t, {required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final unread = t.i('unread') > 0;
    final avatar = t['person'] is Map
        ? XAvatar(t.m('person'), size: 48)
        : XAvatar({'initial': t.s('initial'), 'name': t.s('name')}, size: 48, square: true, ink: true);
    return Semantics(
      button: true,
      label: '${t.s('name')}${unread ? ', ${t.i('unread')} unread' : ''}',
      child: Press(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(t.s('name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: XT.body(context).copyWith(fontSize: 15, fontWeight: unread ? FontWeight.w600 : FontWeight.w500)),
                  ),
                  Text(t.s('time'), style: XT.small(context).copyWith(fontSize: 12)),
                ]),
                const SizedBox(height: 3),
                Text(t.s('last'), maxLines: 1, overflow: TextOverflow.ellipsis, style: XT.small(context, color: unread ? c.ink : null)),
              ]),
            ),
            if (unread) ...[const SizedBox(width: 10), _badge(context, t.i('unread'))],
          ]),
        ),
      ),
    );
  }
}

class _NewMessageSheet extends StatelessWidget {
  const _NewMessageSheet();
  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => Map<String, dynamic>.from(await Api.i.get('social/?tab=following') as Map),
        builder: (context, d, _) => XSheetBody(children: [
          const XSheetHead('New message', sub: 'People you follow'),
          if (d.l('items').isEmpty) Text('Follow someone first, then message them here.', style: XT.small(context)),
          for (final p in d.l('items'))
            XRow(
              p.s('name'),
              sub: '@${p.s('handle')}',
              leading: XAvatar(p, size: 40),
              onTap: () async {
                final r = await attempt(context, () => Api.i.post('threads/start/', {'user_id': p.i('id')}));
                if (r != null && context.mounted) Navigator.pop(context, (r as Map)['thread_id'] as int);
              },
            ),
          gap16,
        ]),
      );
}

/// One conversation. Polls every 4 s for new messages while open.
class ThreadScreen extends StatefulWidget {
  final int threadId;
  const ThreadScreen({super.key, required this.threadId});
  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  Json _head = {};
  final List<Json> _msgs = [];
  bool _loading = true, _sending = false;
  String? _error;
  Timer? _poll;
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _fetchNew());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = Map<String, dynamic>.from(await Api.i.get('threads/${widget.threadId}/') as Map);
      if (!mounted) return;
      setState(() {
        _head = d;
        _msgs
          ..clear()
          ..addAll(d.l('messages'));
        _loading = false;
        _error = null;
      });
      _toBottom(jump: true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  Future<void> _fetchNew() async {
    if (_loading || _error != null || _sending) return;
    final last = _msgs.isEmpty ? 0 : _msgs.last.i('id');
    try {
      final d = Map<String, dynamic>.from(await Api.i.get('threads/${widget.threadId}/?after=$last') as Map);
      final fresh = d.l('messages').where((m) => m.i('id') > last).toList();
      if (fresh.isNotEmpty && mounted) {
        setState(() => _msgs.addAll(fresh));
        _toBottom();
      }
    } catch (_) {}
  }

  void _toBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      jump ? _scroll.jumpTo(max) : _scroll.animateTo(max, duration: context.anim(XS.base), curve: XS.ease);
    });
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    final last = _msgs.isEmpty ? 0 : _msgs.last.i('id');
    setState(() => _sending = true);
    _text.clear();
    try {
      await Api.i.post('threads/${widget.threadId}/', {'text': text});
      final d = Map<String, dynamic>.from(await Api.i.get('threads/${widget.threadId}/?after=$last') as Map);
      if (!mounted) return;
      setState(() => _msgs.addAll(d.l('messages').where((m) => m.i('id') > last)));
      _toBottom();
    } on ApiError catch (e) {
      if (mounted) {
        _text.text = text;
        context.say(e.message);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final title = _head.s('name', 'Messages');
    return XScreen(
      body: Column(children: [
        XTopBar(title, actions: [
          if (_head['person'] is Map)
            XIconBtn(Icons.person_outline_rounded, tooltip: 'View profile', onTap: () => Go.person(context, _head.m('person').i('id'))),
        ]),
        Expanded(
          child: _loading
              ? const Padding(padding: EdgeInsets.all(XS.gutter), child: XSkeleton())
              : _error != null
                  ? XError(_error!, onRetry: () {
                      setState(() => _loading = true);
                      _load();
                    })
                  : _msgs.isEmpty
                      ? XEmpty(icon: Icons.chat_bubble_outline_rounded, title: 'Say hello', body: 'Messages you send show up here.')
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(XS.gutter, 8, XS.gutter, 16),
                          itemCount: _msgs.length,
                          itemBuilder: (context, i) {
                            final m = _msgs[i];
                            final showName = _head.b('group') && !m.b('me') && (i == 0 || _msgs[i - 1].s('from') != m.s('from'));
                            return _Bubble(m, showName: showName);
                          },
                        ),
        ),
        Container(
          decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
          padding: EdgeInsets.fromLTRB(XS.gutter, 10, XS.gutter, 10 + MediaQuery.of(context).padding.bottom),
          child: Row(children: [
            Expanded(
              child: XField(
                controller: _text,
                hint: 'Message',
                action: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Send',
              child: Press(
                onTap: _send,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                  child: _sending
                      ? Padding(padding: const EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2, color: c.onInk))
                      : Icon(Icons.send_rounded, size: 18, color: c.onInk),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Json m;
  final bool showName;
  const _Bubble(this.m, {this.showName = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final me = m.b('me');
    final card = m.m('card');
    Widget body;
    if (card.isNotEmpty) {
      final isChallenge = card.s('kind') == 'challenge' && card.i('id') > 0;
      body = Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(XS.r3), border: Border.all(color: c.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          XKicker(isChallenge ? 'Challenge' : (card.s('kind').isEmpty ? 'Shared' : card.s('kind')[0].toUpperCase() + card.s('kind').substring(1))),
          gap4,
          Text(card.s('title'), style: XT.body(context).copyWith(fontSize: 15, fontWeight: FontWeight.w500)),
          if (card.s('sub').isNotEmpty) ...[const SizedBox(height: 2), Text(card.s('sub'), style: XT.small(context))],
          if (isChallenge) ...[gap8, XLink('Open challenge', onTap: () => Go.challenge(context, card.i('id')))],
          if (m.s('text').isNotEmpty) ...[gap8, Text(m.s('text'), style: XT.body(context))],
        ]),
      );
    } else {
      body = Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .74),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: me ? c.ink : c.gray,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(me ? 18 : 6),
            bottomRight: Radius.circular(me ? 6 : 18),
          ),
        ),
        child: Text(m.s('text'), style: XT.body(context, color: me ? c.onInk : c.ink)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: me ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        if (showName) Padding(padding: const EdgeInsets.only(left: 4, bottom: 3), child: Text(m.s('from').split(' ').first, style: XT.small(context).copyWith(fontSize: 12))),
        body,
        Padding(padding: const EdgeInsets.fromLTRB(4, 3, 4, 0), child: Text(m.s('time'), style: XT.small(context).copyWith(fontSize: 11))),
      ]),
    );
  }
}
