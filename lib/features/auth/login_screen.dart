import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'forgot_screen.dart';

/// Build with --dart-define=EXERLIO_DEMO=true to show the demo-account button.
const bool kDemoLogin = bool.fromEnvironment('EXERLIO_DEMO');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  String _err = '';
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login([String? id, String? pass]) async {
    final ident = (id ?? _id.text).trim();
    final pw = pass ?? _pass.text;
    if (!(ident.contains('@') || RegExp(r'^(\+91)?\d{10}$').hasMatch(ident.replaceAll(' ', '')))) {
      return setState(() => _err = 'Use a valid email or a 10-digit mobile number.');
    }
    if (pw.length < 6) return setState(() => _err = 'Password needs at least 6 characters.');
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final r = await Api.i.post('auth/login/', {'identifier': ident, 'password': pw});
      if (!mounted) return;
      final nav = Navigator.of(context);
      final app = context.app;
      await app.signIn(Map<String, dynamic>.from(r as Map));
      app.say('Welcome back, ${app.me.s('name').split(' ').first}');
      nav.popUntil((r) => r.isFirst);
    } on ApiError catch (e) {
      setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Column(children: [
        const XTopBar(''),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 12, XS.gutter, 24), children: [
            Text('Welcome back', style: XT.h1(context)),
            gap24,
            const XLabel('Email or mobile'),
            gap8,
            XField(controller: _id, hint: 'you@example.com', keyboard: TextInputType.emailAddress, action: TextInputAction.next,
                onChanged: (_) => setState(() => _err = '')),
            gap16,
            const XLabel('Password'),
            gap8,
            XField(controller: _pass, hint: 'Your password', obscure: true, onSubmitted: (_) => _login(),
                onChanged: (_) => setState(() => _err = '')),
            if (_err.isNotEmpty) ...[
              gap12,
              Row(children: [const XDot(), const SizedBox(width: 8), Expanded(child: Text(_err, style: XT.small(context, color: c.ink)))]),
            ],
            gap8,
            Align(alignment: Alignment.centerLeft, child: XLink('Forgot password', underline: true, onTap: () => context.push(ForgotScreen(prefill: _id.text)))),
          ]),
        ),
      ]),
      dock: XDock(children: [
        XButton('Sign in', loading: _busy, onTap: () => _login()),
        if (kDemoLogin) XButton('Use the demo account', kind: XBtn.secondary, onTap: () => _login('akif@exerlio.in', 'Exerlio@123')),
      ]),
    );
  }
}
