import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// First screen: create an account or log in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return XScreen(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(XS.gutter, 56, XS.gutter, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Wordmark(size: 20),
          const Spacer(),
          Text(context.genz ? 'MOVE WITH\nPURPOSE.' : 'Move with\npurpose.', style: XT.hero(context).copyWith(fontSize: 56, height: 1)),
          gap20,
          Text('Train. Track. Recover. Connect.', style: XT.h3(context)),
          gap8,
          Text('A clear fitness experience built around every way people move.', style: XT.body(context, color: c.muted)),
          const Spacer(),
          XButton('Create account', onTap: () => context.push(const SignupScreen())),
          gap8,
          XButton('I already have an account', kind: XBtn.secondary, onTap: () => context.push(const LoginScreen())),
          gap12,
          Center(child: Text('Free to use. Setup takes about a minute.', style: XT.small(context))),
        ]),
      ),
    );
  }
}
