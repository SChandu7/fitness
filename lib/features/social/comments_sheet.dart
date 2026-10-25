import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// Comments for a post or reel. [base] is "posts/12" or "reels/3".
Future<void> showComments(BuildContext context, String base, {VoidCallback? onAdded}) async {
  List<Json> items = [];
  try {
    items = Map<String, dynamic>.from(await Api.i.get('$base/comments/') as Map).l('items');
  } on ApiError catch (e) {
    if (context.mounted) context.say(e.message);
    return;
  }
  if (!context.mounted) return;
  final input = TextEditingController();
  return showXSheet(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(XS.gutter, 0, XS.gutter, 16 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const XSheetHead('Comments'),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              if (items.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text('No comments yet. Start the conversation.', style: XT.small(ctx))),
              for (final c in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    XAvatar(c.m('author'), size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${c.m('author').s('name')} · ${c.s('time')}', style: XT.small(ctx, color: ctx.c.ink).copyWith(fontWeight: FontWeight.w500, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text(c.s('body'), style: XT.body(ctx).copyWith(fontSize: 14)),
                      ]),
                    ),
                  ]),
                ),
            ]),
          ),
          Row(children: [
            Expanded(child: XField(controller: input, hint: 'Add a comment', autofocus: true, action: TextInputAction.send)),
            const SizedBox(width: 8),
            XIconBtn(Icons.send_rounded, tooltip: 'Post comment', onTap: () async {
              final t = input.text.trim();
              if (t.isEmpty) return;
              final r = await attempt(context, () => Api.i.post('$base/comments/', {'body': t}));
              if (r != null) {
                input.clear();
                onAdded?.call();
                set(() => items = Map<String, dynamic>.from(r as Map).l('items'));
              }
            }),
          ]),
        ]),
      ),
    ),
  );
}
