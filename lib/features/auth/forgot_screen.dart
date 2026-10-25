import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Password reset: get a 6-digit code by email, then set a new password.
class ForgotScreen extends StatefulWidget {
  final String prefill;
  const ForgotScreen({super.key, this.prefill = ''});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  late final _id = TextEditingController(text: widget.prefill);
  final _code = TextEditingController();
  final _pass = TextEditingController();
  bool _sent = false, _busy = false;
  String _msg = '';

  @override
  void dispose() {
    _id.dispose();
    _code.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final r = await Api.i.post('auth/forgot/', {'identifier': _id.text.trim()}) as Map;
      setState(() {
        _sent = true;
        _msg = '${r['message']}';
      });
    } on ApiError catch (e) {
      setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      final r = await Api.i.post('auth/reset/', {'identifier': _id.text.trim(), 'code': _code.text.trim(), 'password': _pass.text});
      if (!mounted) return;
      final nav = Navigator.of(context);
      final app = context.app;
      await app.signIn(Map<String, dynamic>.from(r as Map));
      app.say('Password changed. You are signed in.');
      nav.popUntil((r) => r.isFirst);
    } on ApiError catch (e) {
      setState(() => _msg = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return XScreen(
      body: Column(children: [
        const XTopBar(''),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 12, XS.gutter, 24), children: [
            Text(_sent ? 'Check your email' : 'Reset your password', style: XT.h1(context)),
            gap8,
            Text(_sent ? 'Enter the 6-digit code we sent and choose a new password.' : 'We will email you a 6-digit code.',
                style: XT.small(context)),
            gap24,
            const XLabel('Email or mobile'),
            gap8,
            XField(controller: _id, hint: 'you@example.com', keyboard: TextInputType.emailAddress),
            if (_sent) ...[
              gap16,
              const XLabel('Code'),
              gap8,
              XField(controller: _code, hint: '6 digits', keyboard: TextInputType.number),
              gap16,
              const XLabel('New password'),
              gap8,
              XField(controller: _pass, hint: 'At least 6 characters', obscure: true),
            ],
            if (_msg.isNotEmpty) ...[gap12, Text(_msg, style: XT.small(context, color: context.c.ink))],
          ]),
        ),
      ]),
      dock: XDock(children: [
        XButton(_sent ? 'Set new password' : 'Send code', loading: _busy, onTap: _sent ? _reset : _send),
        if (_sent) XButton('Send the code again', kind: XBtn.ghost, onTap: _send),
      ]),
    );
  }
}
