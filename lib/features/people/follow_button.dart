import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../routes.dart';

/// Follow / Following / Request / Requested. Private accounts get a request.
class FollowButton extends StatefulWidget {
  final Json user;
  final bool full;
  final String? followLabel;
  final VoidCallback? onChanged;
  const FollowButton({super.key, required this.user, this.full = false, this.followLabel, this.onChanged});
  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  late bool following = widget.user.b('following'), requested = widget.user.b('requested');
  bool busy = false;

  @override
  void didUpdateWidget(FollowButton old) {
    super.didUpdateWidget(old);
    if (old.user != widget.user) {
      following = widget.user.b('following');
      requested = widget.user.b('requested');
    }
  }

  Future<void> _tap() async {
    if (following) {
      final ok = await confirmX(context, title: 'Unfollow ${widget.user.s('name')}?', body: 'You can follow again any time.', ok: 'Unfollow');
      if (!ok) return;
    }
    setState(() => busy = true);
    final r = await attempt(context, () => Api.i.post('users/${widget.user.i('id')}/follow/'));
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) {
      final m = r as Map;
      setState(() {
        following = m['following'] == true;
        requested = m['requested'] == true;
      });
      context.say('${m['message']}');
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = following ? 'Following' : requested ? 'Requested' : (widget.user.b('is_private') ? 'Request' : (widget.followLabel ?? 'Follow'));
    return XButton(label, small: true, expand: widget.full, loading: busy, kind: following || requested ? XBtn.secondary : XBtn.primary, onTap: _tap);
  }
}

/// Person row with avatar, name (lock if private), tagline and the follow button.
class PersonRow extends StatelessWidget {
  final Json p;
  final Widget? trailing;
  final String? sub;
  const PersonRow(this.p, {super.key, this.trailing, this.sub});
  @override
  Widget build(BuildContext context) => XRow(
        p.s('name'),
        sub: sub ?? p.s('tagline'),
        leading: XAvatar(p, size: 44),
        trailing: trailing ?? FollowButton(user: p),
        onTap: () => Go.person(context, p.i('id')),
      );
}

/// Name with a small lock for private accounts.
class NameWithLock extends StatelessWidget {
  final Json p;
  final TextStyle? style;
  const NameWithLock(this.p, {super.key, this.style});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(p.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: style ?? XT.h3(context))),
        if (p.b('is_private')) ...[const SizedBox(width: 6), Icon(Icons.lock_outline_rounded, size: 14, color: context.c.muted)],
      ]);
}
