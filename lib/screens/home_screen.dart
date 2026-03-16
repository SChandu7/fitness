import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/demo_data.dart';
import '../widgets/common_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late List<Animation<double>> _itemAnimations;

  final int _itemCount = 8;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _itemAnimations = List.generate(_itemCount, (i) {
      final start = (i * 0.08).clamp(0.0, 0.7);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _fadeCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    return FadeTransition(
      opacity: _itemAnimations[index.clamp(0, _itemCount - 1)],
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _fadeCtrl,
          curve: Interval(
            (index * 0.08).clamp(0.0, 0.7),
            ((index * 0.08) + 0.35).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        )),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _animated(0, _buildHeroCard()),
                const SizedBox(height: 16),
                _animated(1, _buildQuickStats()),
                const SizedBox(height: 20),
                _animated(2, _buildCalorieRing()),
                const SizedBox(height: 20),
                _animated(3, _buildMacroSection()),
                const SizedBox(height: 20),
                _animated(4, _buildWeeklyChart()),
                const SizedBox(height: 20),
                _animated(5, _buildTodayWorkout()),
                const SizedBox(height: 20),
                _animated(6, _buildInsightCard()),
                const SizedBox(height: 20),
                _animated(7, _buildChallengePreview()),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: false,
      backgroundColor: AppColors.black,
      title: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning 👋',
                style: AppTextStyles.cardSubtitle.copyWith(fontSize: 12),
              ),
              Text(
                DemoUser.fullName,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          StreakBadge(count: DemoUser.streak),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.orangeGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                DemoUser.name[0],
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return DarkCard(
      glowing: true,
      padding: const EdgeInsets.all(0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Subtle background pattern
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A0800), AppColors.blackCard],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.orange.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.orangeFaint,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.orange.withOpacity(0.3)),
                        ),
                        child: Text(
                          DemoUser.goal.toUpperCase(),
                          style: AppTextStyles.sectionLabel.copyWith(color: AppColors.orange),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.notifications_outlined, color: AppColors.grey500, size: 22),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "Today's\n",
                          style: AppTextStyles.cardSubtitle.copyWith(fontSize: 14, height: 1.3),
                        ),
                        TextSpan(
                          text: 'Plan',
                          style: AppTextStyles.displayHero.copyWith(fontSize: 40),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _heroStat('1,680', 'kcal\nconsumed', AppColors.orange),
                      _heroDivider(),
                      _heroStat('420', 'kcal\nburned', AppColors.info),
                      _heroDivider(),
                      _heroStat('98g', 'protein\nso far', AppColors.success),
                    ],
                  ),
                  const SizedBox(height: 18),
                  OrangeButton(
                    label: 'Start Today\'s Workout',
                    icon: Icons.play_arrow_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.statNumber.copyWith(
                fontSize: 22,
                color: color,
              )),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: AppTextStyles.statUnit.copyWith(height: 1.4)),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(width: 1, height: 40, color: AppColors.blackBorder);
  }

  Widget _buildQuickStats() {
    final stats = [
      ('${DemoUser.bodyFat}%', 'Body Fat', AppColors.orange, Icons.monitor_weight_rounded),
      ('${DemoUser.weight}kg', 'Weight', AppColors.info, Icons.scale_rounded),
      ('${DemoUser.weeklyWorkouts}/5', 'This week', AppColors.success, Icons.fitness_center),
      ('${BodyMetrics.metabolicAge} yr', 'Metabolic age', AppColors.warning, Icons.bolt_rounded),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = stats[i];
          return DarkCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: s.$3.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(s.$4, color: s.$3, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(s.$1,
                        style: AppTextStyles.statNumber.copyWith(
                          fontSize: 18,
                          color: s.$3,
                        )),
                    Text(s.$2, style: AppTextStyles.statUnit),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalorieRing() {
    final consumed = NutritionData.caloriesConsumed;
    final goal = NutritionData.caloriesGoal;
    final progress = consumed / goal;

    return DarkCard(
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 10,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.blackElevated),
                  ),
                ),
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$consumed',
                      style: AppTextStyles.statNumber.copyWith(fontSize: 20),
                    ),
                    Text('kcal', style: AppTextStyles.statUnit),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Calories', style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${NutritionData.caloriesRemaining} kcal remaining',
                  style: AppTextStyles.cardSubtitle,
                ),
                const SizedBox(height: 14),
                _calRingRow('Consumed', consumed, goal, AppColors.orange),
                const SizedBox(height: 8),
                _calRingRow('Burned', 420, 600, AppColors.info),
                const SizedBox(height: 8),
                _calRingRow('Remaining', NutritionData.caloriesRemaining, goal, AppColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calRingRow(String label, int value, int max, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.cardSubtitle.copyWith(fontSize: 12)),
        const Spacer(),
        Text('$value', style: AppTextStyles.cardTitle.copyWith(color: color, fontSize: 13)),
      ],
    );
  }

  Widget _buildMacroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Macros Today', action: 'Log meal'),
        const SizedBox(height: 14),
        DarkCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: MacroPill(
                      label: 'Protein',
                      consumed: NutritionData.proteinConsumed,
                      total: NutritionData.proteinGoal,
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MacroPill(
                      label: 'Carbs',
                      consumed: NutritionData.carbsConsumed,
                      total: NutritionData.carbsGoal,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MacroPill(
                      label: 'Fats',
                      consumed: NutritionData.fatConsumed,
                      total: NutritionData.fatGoal,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orangeFaint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.orange.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Need ${NutritionData.proteinRemaining}g more protein across your remaining meals today',
                        style: AppTextStyles.cardSubtitle.copyWith(color: AppColors.orangeLight, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Weekly Activity', action: 'Details'),
        const SizedBox(height: 14),
        DarkCard(
          child: Column(
            children: [
              Row(
                children: [
                  StatBox(
                    value: '2,400',
                    unit: 'kcal',
                    label: 'TOTAL BURNED',
                    valueColor: AppColors.orange,
                  ),
                  const SizedBox(width: 24),
                  StatBox(
                    value: '48',
                    unit: 'min avg',
                    label: 'AVG DURATION',
                    valueColor: AppColors.info,
                  ),
                  const SizedBox(width: 24),
                  StatBox(
                    value: '4',
                    unit: 'of 5',
                    label: 'SESSIONS',
                    valueColor: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 600,
                    minY: 0,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                days[value.toInt()],
                                style: AppTextStyles.sectionLabel.copyWith(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 200,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppColors.blackBorder,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: WeeklyStats.caloriesBurned
                        .asMap()
                        .entries
                        .map((e) => BarChartGroupData(
                              x: e.key,
                              barRods: [
                                BarChartRodData(
                                  toY: e.value,
                                  gradient: e.value == 0
                                      ? null
                                      : LinearGradient(
                                          colors: e.key == WeeklyStats.restDaySuggestion
                                              ? [AppColors.warning.withOpacity(0.4), AppColors.warning.withOpacity(0.2)]
                                              : [AppColors.orangeLight, AppColors.orangeDark],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                  color: e.value == 0 ? AppColors.blackElevated : null,
                                  width: 22,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.4), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text('Rest day (auto-detected)', style: AppTextStyles.statUnit.copyWith(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayWorkout() {
    final workout = DemoWorkouts.sessions.first;
    final completedCount = workout.exercises.where((e) => e.isCompleted).length;
    final totalCount = workout.exercises.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: "Today's Workout", action: 'See all'),
        const SizedBox(height: 14),
        DarkCard(
          glowing: true,
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.orangeGlow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(workout.icon, color: AppColors.orange, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(workout.name, style: AppTextStyles.cardTitle),
                        const SizedBox(height: 2),
                        Text(
                          '${workout.duration} min  •  ${workout.calories} kcal  •  ${workout.difficulty}',
                          style: AppTextStyles.cardSubtitle,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$completedCount/$totalCount',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completedCount / totalCount,
                  backgroundColor: AppColors.blackElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 14),
              ...workout.exercises.take(3).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          e.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: e.isCompleted ? AppColors.success : AppColors.grey500,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          e.name,
                          style: AppTextStyles.cardSubtitle.copyWith(
                            color: e.isCompleted ? AppColors.grey500 : AppColors.white,
                            decoration: e.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${e.sets}×${e.reps}',
                          style: AppTextStyles.orangeAccent.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  )),
              if (workout.exercises.length > 3)
                Text(
                  '+${workout.exercises.length - 3} more exercises',
                  style: AppTextStyles.cardSubtitle.copyWith(fontSize: 12),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard() {
    return DarkCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.insights_rounded, color: AppColors.warning, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Insulin Spike Detected 🍽️', style: AppTextStyles.cardTitle),
                const SizedBox(height: 3),
                Text(
                  'Your last meal may cause a glucose spike. A 10-min walk now can reduce it by 30%.',
                  style: AppTextStyles.cardSubtitle.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.arrow_forward_ios_rounded, color: AppColors.grey500, size: 14),
        ],
      ),
    );
  }

  Widget _buildChallengePreview() {
    final c = DemoChallenges.active.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Active Challenges', action: 'View all'),
        const SizedBox(height: 14),
        DarkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppColors.orangeGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        c.avatar,
                        style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('vs ${c.name}', style: AppTextStyles.cardTitle),
                        Text(c.challengeType, style: AppTextStyles.cardSubtitle),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${c.daysLeft}d left',
                      style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _challengeBar('You', c.myProgress, AppColors.orange),
              const SizedBox(height: 8),
              _challengeBar(c.name, c.theirProgress, AppColors.grey500),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _emojiReaction('💪'),
                  const SizedBox(width: 8),
                  _emojiReaction('🔥'),
                  const SizedBox(width: 8),
                  _emojiReaction('👊'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _challengeBar(String label, double progress, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: AppTextStyles.statUnit.copyWith(fontSize: 11)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.blackElevated,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
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

  Widget _emojiReaction(String emoji) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.blackElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.blackBorder),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
