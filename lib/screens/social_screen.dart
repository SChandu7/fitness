import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/demo_data.dart';
import '../widgets/common_widgets.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with TickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: AppColors.black,
            floating: true,
            title: Text('Community', style: AppTextStyles.cardTitle.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_outlined, color: AppColors.white),
                onPressed: () {},
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.orange,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.orange,
              unselectedLabelColor: AppColors.grey500,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Challenges'),
                Tab(text: 'Friends'),
                Tab(text: 'Leaderboard'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildChallengesTab(),
            _buildFriendsTab(),
            _buildLeaderboardTab(),
          ],
        ),
      ),
    );
  }

  // ── Challenges Tab ────────────────────────────────────────────────────────────

  Widget _buildChallengesTab() {
    final challengeTypes = [
      (Icons.directions_run_rounded, 'Running', '12 active', AppColors.orange),
      (Icons.pool_rounded, 'Swimming', '5 active', AppColors.info),
      (Icons.directions_bike_rounded, 'Cycling', '8 active', AppColors.success),
      (Icons.hiking_rounded, 'Trekking', '3 active', AppColors.warning),
      (Icons.sports_tennis_rounded, 'Badminton', '6 active', AppColors.danger),
      (Icons.self_improvement_rounded, 'Yoga', '9 active', const Color(0xFFB57BEE)),
      (Icons.monitor_weight_rounded, 'Fat Loss %', '14 active', AppColors.orangeLight),
      (Icons.photo_camera_rounded, 'Photo Challenge', '7 active', AppColors.grey300),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SectionHeader(title: 'Active Challenges'),
              const SizedBox(height: 14),
              ...DemoChallenges.active.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildChallengeCard(c),
                  )),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Browse Categories', action: 'Create new'),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.0,
                children: challengeTypes.map((c) {
                  return GestureDetector(
                    onTap: () {},
                    child: DarkCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(c.$1, color: c.$4, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(c.$2, style: AppTextStyles.cardTitle.copyWith(fontSize: 13)),
                              Text(c.$3, style: AppTextStyles.cardSubtitle.copyWith(fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildChallengeCard(FriendChallenge c) {
    final isWinning = c.myProgress > c.theirProgress;

    return DarkCard(
      glowing: isWinning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.orangeGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(c.avatar,
                      style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.challengeType, style: AppTextStyles.cardTitle),
                    Text('vs ${c.name}', style: AppTextStyles.cardSubtitle),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${c.daysLeft}d left',
                        style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isWinning ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: isWinning ? AppColors.success : AppColors.danger,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isWinning ? 'You\'re ahead!' : 'Behind',
                        style: TextStyle(
                          color: isWinning ? AppColors.success : AppColors.danger,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _vsProgressBar('You', c.myProgress, AppColors.orange, true),
          const SizedBox(height: 8),
          _vsProgressBar(c.name, c.theirProgress, AppColors.grey500, false),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: ['💪', '🔥', '👊', '🎯']
                    .map((emoji) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.blackElevated,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(emoji, style: const TextStyle(fontSize: 14)),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              Text('Tap to react', style: AppTextStyles.statUnit.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vsProgressBar(String label, double progress, Color color, bool isMe) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: AppTextStyles.statUnit.copyWith(
              fontSize: 11,
              fontWeight: isMe ? FontWeight.w600 : FontWeight.w400,
              color: isMe ? AppColors.white : AppColors.grey300,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.blackElevated,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(progress * 100).toInt()}%',
          style: AppTextStyles.cardTitle.copyWith(fontSize: 12, color: color),
        ),
      ],
    );
  }

  // ── Friends Tab ───────────────────────────────────────────────────────────────

  Widget _buildFriendsTab() {
    final friends = [
      ('Rahul K.', 'R', 14, true, 'Leg Day'),
      ('Priya S.', 'P', 8, true, 'Yoga'),
      ('Dev M.', 'D', 22, false, 'Rest'),
      ('Aisha T.', 'A', 5, true, 'Running'),
      ('Karan B.', 'K', 31, true, 'Upper Body'),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Your streak summary
              DarkCard(
                glowing: true,
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Streak', style: AppTextStyles.cardTitle),
                        Text('${DemoUser.streak} days — keep going!', style: AppTextStyles.cardSubtitle),
                      ],
                    ),
                    const Spacer(),
                    StreakBadge(count: DemoUser.streak),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SectionHeader(
                title: 'Friends (${friends.length})',
                action: 'Add friends',
              ),
              const SizedBox(height: 14),
              ...friends.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DarkCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.blackSurface, AppColors.blackElevated],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.blackBorder),
                              ),
                              child: Center(
                                child: Text(f.$2,
                                    style: const TextStyle(
                                        color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                            ),
                            if (f.$4)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.black, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.$1, style: AppTextStyles.cardTitle),
                              Text(
                                f.$4 ? 'Active: ${f.$5}' : 'Rest day',
                                style: AppTextStyles.cardSubtitle.copyWith(
                                  fontSize: 11,
                                  color: f.$4 ? AppColors.success : AppColors.grey500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 3),
                                Text('${f.$3}', style: AppTextStyles.cardTitle.copyWith(fontSize: 13, color: AppColors.orange)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: ['💪', '👊']
                                  .map((emoji) => Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: GestureDetector(
                                          onTap: () {},
                                          child: Text(emoji, style: const TextStyle(fontSize: 16)),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Leaderboard Tab ───────────────────────────────────────────────────────────

  Widget _buildLeaderboardTab() {
    final entries = [
      ('Karan B.', 'K', 31, 4820, 1),
      ('Rahul K.', 'R', 14, 4210, 2),
      ('You', 'A', 12, 3980, 3),
      ('Priya S.', 'P', 8, 3540, 4),
      ('Aisha T.', 'A', 5, 2990, 5),
      ('Dev M.', 'D', 22, 2750, 6),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Top 3 podium
              _buildPodium(entries.take(3).toList()),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Full Rankings'),
              const SizedBox(height: 14),
              ...entries.asMap().entries.map((entry) {
                final i = entry.key;
                final person = entry.value;
                final isMe = person.$1 == 'You';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DarkCard(
                    glowing: isMe,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${person.$5}',
                            style: AppTextStyles.statNumber.copyWith(
                              fontSize: 18,
                              color: person.$5 == 1
                                  ? const Color(0xFFFFD700)
                                  : person.$5 == 2
                                      ? const Color(0xFFC0C0C0)
                                      : person.$5 == 3
                                          ? const Color(0xFFCD7F32)
                                          : AppColors.grey500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: isMe ? AppColors.orangeGradient : null,
                            color: isMe ? null : AppColors.blackElevated,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(person.$2,
                                style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 14,
                                    fontWeight: isMe ? FontWeight.w700 : FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person.$1,
                                style: AppTextStyles.cardTitle.copyWith(
                                  color: isMe ? AppColors.orange : AppColors.white,
                                ),
                              ),
                              Row(
                                children: [
                                  const Text('🔥', style: TextStyle(fontSize: 10)),
                                  const SizedBox(width: 3),
                                  Text('${person.$3} day streak',
                                      style: AppTextStyles.cardSubtitle.copyWith(fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${person.$4} pts',
                          style: AppTextStyles.statNumber.copyWith(
                            fontSize: 16,
                            color: isMe ? AppColors.orange : AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildPodium(List<dynamic> top3) {
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          Expanded(
            child: _podiumColumn(top3[1], 2, 100, const Color(0xFFC0C0C0)),
          ),
          const SizedBox(width: 6),
          // 1st place
          Expanded(
            child: _podiumColumn(top3[0], 1, 130, const Color(0xFFFFD700)),
          ),
          const SizedBox(width: 6),
          // 3rd place
          Expanded(
            child: _podiumColumn(top3[2], 3, 80, const Color(0xFFCD7F32)),
          ),
        ],
      ),
    );
  }

  Widget _podiumColumn(dynamic person, int rank, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(rank == 1 ? '👑' : '  ', style: const TextStyle(fontSize: 18)),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(person.$2,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 4),
        Text(person.$1.split(' ')[0], style: AppTextStyles.cardSubtitle.copyWith(fontSize: 11)),
        Text('${person.$4}', style: AppTextStyles.cardTitle.copyWith(fontSize: 11, color: color)),
        const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

// Purple accent used in social screen challenge categories
