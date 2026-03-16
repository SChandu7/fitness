import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/demo_data.dart';
import '../widgets/common_widgets.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  bool _activeWorkout = false;
  int _activeSessionIndex = 0;
  int _completedExercises = 2;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: _activeWorkout ? _buildActiveWorkout() : _buildWorkoutBrowser(),
    );
  }

  // ── Workout Browser ──────────────────────────────────────────────────────────

  Widget _buildWorkoutBrowser() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.black,
          floating: true,
          title: Text('Workouts', style: AppTextStyles.cardTitle.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.white),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: AppColors.white),
              onPressed: () {},
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildCategoryScroll(),
              const SizedBox(height: 20),
              _buildFeaturedSession(),
              const SizedBox(height: 20),
              const SectionHeader(title: 'All Workouts', action: 'Create custom'),
              const SizedBox(height: 14),
              ...DemoWorkouts.sessions.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildWorkoutCard(w, DemoWorkouts.sessions.indexOf(w)),
                  )),
              const SizedBox(height: 20),
              _buildRestDayBanner(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryScroll() {
    final categories = [
      (Icons.all_inclusive_rounded, 'All', true),
      (Icons.fitness_center_rounded, 'Strength', false),
      (Icons.directions_run_rounded, 'Cardio', false),
      (Icons.self_improvement_rounded, 'Yoga', false),
      (Icons.pool_rounded, 'Swimming', false),
      (Icons.directions_bike_rounded, 'Cycling', false),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = categories[i].$3;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            decoration: BoxDecoration(
              gradient: active ? AppColors.orangeGradient : null,
              color: active ? null : AppColors.blackCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? Colors.transparent : AppColors.blackBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(categories[i].$1, color: active ? AppColors.white : AppColors.grey300, size: 16),
                const SizedBox(width: 6),
                Text(
                  categories[i].$2,
                  style: TextStyle(
                    color: active ? AppColors.white : AppColors.grey300,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedSession() {
    final w = DemoWorkouts.sessions.first;
    return GestureDetector(
      onTap: () => setState(() {
        _activeWorkout = true;
        _activeSessionIndex = 0;
      }),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1000), Color(0xFF1A1A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.orange.withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.08,
                child: Icon(w.icon, size: 160, color: AppColors.orange),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.orangeGlow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'RECOMMENDED TODAY',
                      style: AppTextStyles.sectionLabel.copyWith(color: AppColors.orange),
                    ),
                  ),
                  const Spacer(),
                  Text(w.name, style: AppTextStyles.displayHero.copyWith(fontSize: 28)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, color: AppColors.grey300, size: 14),
                      const SizedBox(width: 4),
                      Text('${w.duration} min', style: AppTextStyles.cardSubtitle),
                      const SizedBox(width: 14),
                      Icon(Icons.local_fire_department_outlined, color: AppColors.grey300, size: 14),
                      const SizedBox(width: 4),
                      Text('${w.calories} kcal', style: AppTextStyles.cardSubtitle),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: AppColors.orangeGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: AppColors.white, size: 18),
                            const SizedBox(width: 4),
                            Text('Start', style: AppTextStyles.buttonText.copyWith(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(WorkoutSession w, int index) {
    return GestureDetector(
      onTap: () => setState(() {
        _activeWorkout = true;
        _activeSessionIndex = index;
      }),
      child: DarkCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: w.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(w.icon, color: w.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.name, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Text(
                    '${w.exercises.length} exercises  •  ${w.duration} min  •  ${w.calories} kcal',
                    style: AppTextStyles.cardSubtitle.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _difficultyColor(w.difficulty).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    w.difficulty,
                    style: TextStyle(
                      color: _difficultyColor(w.difficulty),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(w.category, style: AppTextStyles.cardSubtitle.copyWith(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestDayBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('😴', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rest day suggested', style: AppTextStyles.cardTitle.copyWith(color: AppColors.warning)),
                const SizedBox(height: 3),
                Text(
                  "You've burned 2,400 kcal this week. Your body needs recovery time for muscle growth.",
                  style: AppTextStyles.cardSubtitle.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Active Workout ────────────────────────────────────────────────────────────

  Widget _buildActiveWorkout() {
    final session = DemoWorkouts.sessions[_activeSessionIndex];
    final totalExercises = session.exercises.length;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.orange.withOpacity(0.1), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _activeWorkout = false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.blackCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.blackBorder),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: AppColors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(session.name, style: AppTextStyles.cardTitle.copyWith(fontSize: 18, fontWeight: FontWeight.w700)),
                            Text('${session.category} • ${session.difficulty}', style: AppTextStyles.cardSubtitle),
                          ],
                        ),
                      ),
                      _LiveTimer(),
                    ],
                  ),
                ),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_completedExercises of $totalExercises completed',
                            style: AppTextStyles.cardSubtitle,
                          ),
                          Text(
                            '${((_completedExercises / totalExercises) * 100).toInt()}%',
                            style: AppTextStyles.orangeAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _completedExercises / totalExercises,
                          backgroundColor: AppColors.blackElevated,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),

                // Live stats row
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: Row(
                    children: [
                      _liveStat('245', 'kcal', Icons.local_fire_department_rounded, AppColors.orange),
                      const SizedBox(width: 10),
                      _liveStat('142', 'bpm', Icons.favorite_rounded, AppColors.danger),
                      const SizedBox(width: 10),
                      _liveStat('4', 'sets done', Icons.check_circle_rounded, AppColors.success),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Exercise list
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    physics: const BouncingScrollPhysics(),
                    itemCount: session.exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final ex = session.exercises[i];
                      final isCompleted = i < _completedExercises;
                      final isActive = i == _completedExercises;
                      return _buildExerciseTile(ex, i, isCompleted, isActive);
                    },
                  ),
                ),

                // Bottom CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OrangeButton(
                          label: _completedExercises < DemoWorkouts.sessions[_activeSessionIndex].exercises.length
                              ? 'Complete Exercise'
                              : 'Finish Workout 🎉',
                          onTap: () {
                            final max = DemoWorkouts.sessions[_activeSessionIndex].exercises.length;
                            if (_completedExercises < max) {
                              setState(() => _completedExercises++);
                            } else {
                              setState(() {
                                _activeWorkout = false;
                                _completedExercises = 0;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveStat(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppTextStyles.cardTitle.copyWith(color: color)),
                Text(label, style: AppTextStyles.statUnit.copyWith(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTile(Exercise ex, int index, bool isCompleted, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppColors.orange.withOpacity(0.08) : AppColors.blackCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.orange.withOpacity(0.4)
              : isCompleted
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.blackBorder,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.success.withOpacity(0.15)
                  : isActive
                      ? AppColors.orangeGlow
                      : AppColors.blackElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check_rounded, color: AppColors.success, size: 18)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isActive ? AppColors.orange : AppColors.grey300,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.name,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: isCompleted ? AppColors.grey500 : AppColors.white,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ex.sets} sets × ${ex.reps} reps  •  ${ex.restSeconds}s rest',
                  style: AppTextStyles.cardSubtitle.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.orangeGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Active', style: AppTextStyles.labelLarge.copyWith(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Color _difficultyColor(String d) {
    switch (d) {
      case 'Easy':
        return AppColors.success;
      case 'Medium':
        return AppColors.warning;
      case 'Hard':
        return AppColors.danger;
      default:
        return AppColors.grey300;
    }
  }
}

/// Self-contained live timer widget
class _LiveTimer extends StatefulWidget {
  @override
  State<_LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<_LiveTimer> {
  int _seconds = 0;
  late final Stream<int> _stream;

  @override
  void initState() {
    super.initState();
    _stream = Stream.periodic(const Duration(seconds: 1), (i) => i + 1);
  }

  String _format(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      builder: (_, snap) {
        _seconds = snap.data ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.orangeGlow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_rounded, color: AppColors.orange, size: 14),
              const SizedBox(width: 5),
              Text(_format(_seconds), style: AppTextStyles.orangeAccent),
            ],
          ),
        );
      },
    );
  }
}
