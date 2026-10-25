import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/ui.dart';
import '../clubs/new_club_screen.dart';
import '../routes.dart';

/// The + in the Home top bar: start, scan, post, reel, story, event, challenge, club.
Future<void> showCreateSheet(BuildContext context) {
  final opts = [
    (Icons.monitor_heart_outlined, 'Start activity', 'Any sport, live tracking', 'start'),
    (Icons.document_scanner_outlined, 'Scan a plate', 'Calories and macros', 'scan'),
    (Icons.image_outlined, 'Post', 'Photos, stats, routes', 'post'),
    (Icons.videocam_outlined, 'Reel', 'Up to 90 s video', 'reel'),
    (Icons.add_circle_outline_rounded, 'Story', 'Gone in 24 h', 'story'),
    (Icons.event_outlined, 'Club event', 'For your club page', 'event'),
    (Icons.flag_outlined, 'Challenge', 'Compete with friends', 'challenge'),
    (Icons.groups_outlined, 'New club or page', 'Crew, gym or coach', 'club'),
  ];
  return showXSheet(
    context,
    (ctx) => XSheetBody(children: [
      const XSheetHead('Create'),
      XGrid(cols: 2, children: [
        for (final o in opts)
          XOption(
            icon: o.$1,
            title: o.$2,
            sub: o.$3,
            onTap: () {
              Navigator.pop(ctx);
              switch (o.$4) {
                case 'start':
                  Go.track(context);
                case 'scan':
                  Go.scan(context);
                case 'challenge':
                  Go.newChallenge(context);
                case 'club':
                  context.push(const NewClubScreen());
                default:
                  Go.compose(context, o.$4);
              }
            },
          ),
      ]),
    ]),
  );
}
