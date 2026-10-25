import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../onboarding/onboarding_screen.dart' show ObHeader;

/// Setup step 1: name, email or mobile, password. Creates the account.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _pass = TextEditingController();
  String _err = '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Add your name.';
    final id = _id.text.trim().replaceAll(' ', '');
    if (!(id.contains('@') || RegExp(r'^(\+91)?\d{10}$').hasMatch(id))) return 'Use a valid email or a 10-digit mobile number.';
    if (_pass.text.length < 6) return 'Password needs at least 6 characters.';
    return null;
  }

  Future<void> _create() async {
    final e = _validate();
    if (e != null) return setState(() => _err = e);
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final r = await Api.i.post('auth/register/', {'name': _name.text.trim(), 'identifier': _id.text.trim(), 'password': _pass.text});
      if (!mounted) return;
      final nav = Navigator.of(context);
      await context.app.signIn(Map<String, dynamic>.from(r as Map));
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
        ObHeader(step: 1, onBack: () => Navigator.pop(context)),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(XS.gutter, 22, XS.gutter, 24), children: [
            Text('Create your account', style: XT.h1(context)),
            gap4,
            Text('Your name is the only thing your squad sees.', style: XT.small(context)),
            gap24,
            const XLabel('What should we call you?'),
            gap8,
            XField(controller: _name, hint: 'Your name', action: TextInputAction.next, onChanged: (_) => setState(() => _err = '')),
            gap16,
            const XLabel('Email or mobile'),
            gap8,
            XField(controller: _id, hint: 'you@example.com or 98xxxxxxxx', keyboard: TextInputType.emailAddress, action: TextInputAction.next,
                onChanged: (_) => setState(() => _err = '')),
            gap16,
            const XLabel('Password'),
            gap8,
            XField(controller: _pass, hint: 'At least 6 characters', obscure: true, onSubmitted: (_) => _create(),
                onChanged: (_) => setState(() => _err = '')),
            if (_err.isNotEmpty) ...[
              gap12,
              Row(children: [const XDot(), const SizedBox(width: 8), Expanded(child: Text(_err, style: XT.small(context, color: c.ink)))]),
            ],
            gap16,
            Text('By creating an account you agree to the Terms and Privacy Policy.', style: XT.small(context)),
          ]),
        ),
      ]),
      dock: XDock(children: [XButton('Continue', loading: _busy, onTap: _create)]),
    );
  }
}
