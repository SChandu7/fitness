import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/track.dart';
import '../../core/ui.dart';

/// Settings → Support: the user's tickets with the Exerlio team, and a way to open a new one.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  Json? _d;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('support/');
      if (mounted) setState(() => (_d = Map<String, dynamic>.from(r as Map), _err = ''));
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.message);
    }
  }

  Future<void> _new() async {
    final created = await showXSheet<Json>(context, (_) => _NewTicketSheet(categories: _d?.l('categories') ?? const []));
    if (created == null || !mounted) return;
    await _load();
    if (mounted) await context.push(SupportTicketScreen(id: created.i('id')));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = _d?.l('items') ?? const <Json>[];
    return XScreen(
      dock: _d == null ? null : XDock(children: [XButton('Contact support', icon: Icons.chat_bubble_outline_rounded, onTap: _new)]),
      body: Column(children: [
        const XTopBar('Support'),
        Expanded(
          child: _d == null
              ? (_err.isNotEmpty
                  ? XError(_err, onRetry: () => setState(() {
                        _err = '';
                        _load();
                      }))
                  : const Padding(padding: EdgeInsets.all(XS.gutter), child: XSkeleton()))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 8, XS.gutter, 32), children: [
                    Text('Write to the Exerlio team about anything: a bug, your account, an idea. '
                        'Replies show here and in your notifications. We usually answer within a day.', style: XT.small(context)),
                    gap20,
                    if (items.isEmpty)
                      XCard(
                        muted: true,
                        child: Column(children: [
                          Icon(Icons.support_agent_rounded, size: 32, color: c.muted),
                          gap8,
                          Text('No conversations yet', style: XT.h3(context)),
                          gap4,
                          Text('Tap Contact support to start one.', style: XT.small(context), textAlign: TextAlign.center),
                        ]),
                      )
                    else ...[
                      const XLabel('Your conversations'),
                      gap8,
                      for (final t in items)
                        XRow(t.s('subject'),
                            sub: '${t.s('number')} · ${t.s('status_label')} · ${t.s('updated')}',
                            leading: Stack(clipBehavior: Clip.none, children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: c.gray, borderRadius: BorderRadius.circular(XS.r2)),
                                child: Icon(t.b('open') ? Icons.chat_bubble_outline_rounded : Icons.check_circle_outline_rounded, size: 20, color: c.ink),
                              ),
                              if (t.b('unread')) const Positioned(right: -2, top: -2, child: XDot(size: 9)),
                            ]),
                            chevron: true, onTap: () async {
                          await context.push(SupportTicketScreen(id: t.i('id')));
                          if (mounted) _load();
                        }),
                    ],
                  ]),
                ),
        ),
      ]),
    );
  }
}

class _NewTicketSheet extends StatefulWidget {
  final List<Json> categories;
  const _NewTicketSheet({required this.categories});
  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _text = TextEditingController();
  String _cat = '';
  bool _busy = false;
  String _err = '';

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _text.text.trim();
    if (_cat.isEmpty) return setState(() => _err = 'Pick what it is about.');
    if (msg.length < 10) return setState(() => _err = 'Tell us a little more, at least a sentence.');
    setState(() => (_busy = true, _err = ''));
    try {
      final r = Map<String, dynamic>.from(await Api.i.post('support/', {
        'category': _cat,
        'message': msg,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'app_version': kAppVersion,
      }) as Map);
      if (!mounted) return;
      context.say(r.s('message'));
      Navigator.pop(context, r.m('ticket'));
    } on ApiError catch (e) {
      if (mounted) setState(() => (_busy = false, _err = e.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    return XSheetBody(children: [
      const XSheetHead('Contact support', sub: 'A real person reads every message.'),
      const XLabel('What is it about?'),
      gap8,
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in widget.categories) XChip(k.s('label'), on: _cat == k.s('key'), onTap: () => setState(() => _cat = k.s('key'))),
      ]),
      gap16,
      const XLabel('Your message'),
      gap8,
      XField(controller: _text, hint: 'What happened, and what did you expect? Steps help us fix it faster.', maxLines: 6),
      if (_err.isNotEmpty) ...[gap8, Text(_err, style: XT.small(context, color: context.c.red))],
      gap16,
      XButton('Send', loading: _busy, onTap: _send),
      gap8,
      Text('Your app version and phone type are attached so we can help. Don\'t send passwords.', style: XT.small(context)),
      gap16,
    ]);
  }
}

/// One conversation with the support team.
class SupportTicketScreen extends StatefulWidget {
  final int id;
  const SupportTicketScreen({super.key, required this.id});
  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  Json? _d;
  String _err = '';
  bool _busy = false;
  final _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('support/${widget.id}/');
      if (mounted) setState(() => (_d = Map<String, dynamic>.from(r as Map), _err = ''));
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.message);
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final r = await Api.i.post('support/${widget.id}/', {'message': text});
      if (!mounted) return;
      _reply.clear();
      setState(() => (_d = Map<String, dynamic>.from(r as Map), _busy = false));
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.say(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final t = _d?.m('ticket') ?? const {};
    final closed = t.s('status') == 'closed';
    return XScreen(
      body: Column(children: [
        XTopBar(t.s('number', 'Support')),
        Expanded(
          child: _d == null
              ? (_err.isNotEmpty ? XError(_err, onRetry: _load) : const Padding(padding: EdgeInsets.all(XS.gutter), child: XSkeleton()))
              : ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 8, XS.gutter, 16), children: [
                  Text(t.s('subject'), style: XT.h2(context)),
                  gap4,
                  Text('${t.s('category_label')} · ${t.s('status_label')}', style: XT.small(context)),
                  gap16,
                  for (final m in _d!.l('messages'))
                    Align(
                      alignment: m.b('from_team') ? Alignment.centerLeft : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: m.b('from_team') ? c.gray : c.ink,
                          borderRadius: BorderRadius.circular(XS.r3),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.b('from_team') ? '${m.s('author')} · Exerlio team' : 'You',
                              style: XT.small(context, color: m.b('from_team') ? c.muted : c.onInk.withValues(alpha: .7)).copyWith(fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(m.s('body'), style: XT.body(context, color: m.b('from_team') ? c.ink : c.onInk)),
                          const SizedBox(height: 4),
                          Text(m.s('time'), style: XT.small(context, color: m.b('from_team') ? c.muted : c.onInk.withValues(alpha: .6)).copyWith(fontSize: 11)),
                        ]),
                      ),
                    ),
                  if (t.s('status') == 'resolved') ...[
                    gap8,
                    XNote(text: 'The team marked this resolved. Write back if you still need help and it reopens.'),
                  ],
                ]),
        ),
        if (_d != null && !closed)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(XS.gutter, 8, XS.gutter, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: XField(controller: _reply, hint: 'Write a reply', maxLines: 1, action: TextInputAction.send, onSubmitted: (_) => _send())),
                const SizedBox(width: 8),
                XButton('Send', expand: false, loading: _busy, onTap: _send),
              ]),
            ),
          ),
        if (closed)
          Padding(padding: const EdgeInsets.all(XS.gutter), child: Text('This conversation is closed. Open a new one from Support.', style: XT.small(context))),
      ]),
    );
  }
}
