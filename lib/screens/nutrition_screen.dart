import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/demo_data.dart';
import '../widgets/common_widgets.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  bool _showScanOverlay = false;
  bool _scanComplete = false;
  late AnimationController _scanCtrl;
  late Animation<double> _scanLine;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _scanCtrl = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _scanLine = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  void _startScan() async {
    setState(() {
      _showScanOverlay = true;
      _scanComplete = false;
    });
    _scanCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 2200));
    _scanCtrl.stop();
    setState(() => _scanComplete = true);
    await Future.delayed(const Duration(milliseconds: 1600));
    setState(() => _showScanOverlay = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: AppColors.black,
                floating: true,
                title: Text('Nutrition', style: AppTextStyles.cardTitle.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
                actions: [
                  GestureDetector(
                    onTap: _startScan,
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: AppColors.orangeGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.camera_alt_rounded, color: AppColors.white, size: 16),
                          const SizedBox(width: 6),
                          Text('Scan Meal', style: AppTextStyles.labelLarge.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildCalorieOverview(),
                    const SizedBox(height: 20),
                    _buildMacrosPieSection(),
                    const SizedBox(height: 20),
                    _buildMealsSection(),
                    const SizedBox(height: 20),
                    _buildMicronutrientsCard(),
                    const SizedBox(height: 20),
                    _buildProteinAlert(),
                  ]),
                ),
              ),
            ],
          ),
          if (_showScanOverlay) _buildScanOverlay(),
        ],
      ),
    );
  }

  Widget _buildCalorieOverview() {
    final consumed = NutritionData.caloriesConsumed;
    final goal = NutritionData.caloriesGoal;
    final burned = 420;
    final net = consumed - burned;

    return DarkCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Caloric Budget', style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Monday, Today', style: AppTextStyles.cardSubtitle),
                ],
              ),
              Text(
                '${goal - net} left',
                style: AppTextStyles.orangeAccent.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _calorieCircle('Consumed', consumed, goal, AppColors.orange),
              _calorieArrow(Icons.remove),
              _calorieCircle('Burned', burned, 600, AppColors.info),
              _calorieArrow(Icons.drag_handle_rounded),
              _calorieCircle('Net', net, goal, AppColors.success),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: consumed / goal,
              backgroundColor: AppColors.blackElevated,
              valueColor: AlwaysStoppedAnimation<Color>(
                consumed / goal > 0.9 ? AppColors.warning : AppColors.orange,
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: AppTextStyles.statUnit),
              Text('Goal: $goal kcal', style: AppTextStyles.statUnit.copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calorieCircle(String label, int value, int max, Color color) {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (value / max).clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: AppColors.blackElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  '$value',
                  style: AppTextStyles.cardTitle.copyWith(color: color, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.statUnit.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _calorieArrow(IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Icon(icon, color: AppColors.grey500, size: 16),
    );
  }

  Widget _buildMacrosPieSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Macronutrients'),
        const SizedBox(height: 14),
        DarkCard(
          child: Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: NutritionData.proteinConsumed.toDouble(),
                        color: AppColors.orange,
                        radius: 28,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: NutritionData.carbsConsumed.toDouble(),
                        color: AppColors.info,
                        radius: 28,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: NutritionData.fatConsumed.toDouble(),
                        color: AppColors.warning,
                        radius: 28,
                        showTitle: false,
                      ),
                    ],
                    centerSpaceRadius: 38,
                    sectionsSpace: 3,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _macroRow('Protein', NutritionData.proteinConsumed, NutritionData.proteinGoal, AppColors.orange),
                    const SizedBox(height: 14),
                    _macroRow('Carbs', NutritionData.carbsConsumed, NutritionData.carbsGoal, AppColors.info),
                    const SizedBox(height: 14),
                    _macroRow('Fats', NutritionData.fatConsumed, NutritionData.fatGoal, AppColors.warning),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _macroRow(String name, int consumed, int goal, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(name, style: AppTextStyles.cardSubtitle.copyWith(fontSize: 13)),
              ],
            ),
            Text('${consumed}g / ${goal}g', style: AppTextStyles.cardTitle.copyWith(fontSize: 12, color: color)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (consumed / goal).clamp(0.0, 1.0),
            backgroundColor: AppColors.blackElevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildMealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Meals Today', action: 'Add meal', onAction: _startScan),
        const SizedBox(height: 14),
        ...DemoMeals.today.map((meal) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildMealCard(meal),
            )),
      ],
    );
  }

  Widget _buildMealCard(MealData meal) {
    final isPending = meal.calories == 0;
    return DarkCard(
      padding: const EdgeInsets.all(14),
      onTap: isPending ? _startScan : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPending ? AppColors.blackElevated : AppColors.orangeFaint,
              borderRadius: BorderRadius.circular(12),
              border: isPending
                  ? Border.all(color: AppColors.blackBorder, style: BorderStyle.solid)
                  : null,
            ),
            child: Center(
              child: Text(
                meal.emoji,
                style: TextStyle(fontSize: isPending ? 20 : 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: isPending ? AppColors.grey500 : AppColors.white,
                    fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(meal.time, style: AppTextStyles.cardSubtitle.copyWith(fontSize: 12)),
              ],
            ),
          ),
          if (!isPending) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${meal.calories}', style: AppTextStyles.statNumber.copyWith(fontSize: 18, color: AppColors.orange)),
                Text('kcal', style: AppTextStyles.statUnit),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mealMacro('P', meal.protein, AppColors.orange),
                _mealMacro('C', meal.carbs, AppColors.info),
                _mealMacro('F', meal.fat, AppColors.warning),
              ],
            ),
          ] else
            Icon(Icons.add_circle_outline_rounded, color: AppColors.orange, size: 22),
        ],
      ),
    );
  }

  Widget _mealMacro(String label, int value, Color color) {
    return Text(
      '$label: ${value}g',
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildMicronutrientsCard() {
    final micros = [
      ('Vitamin D', 0.72, AppColors.warning),
      ('Iron', 0.55, AppColors.danger),
      ('Calcium', 0.88, AppColors.info),
      ('Omega-3', 0.30, AppColors.success),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Micronutrients'),
        const SizedBox(height: 14),
        DarkCard(
          child: Column(
            children: micros
                .map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(m.$1, style: AppTextStyles.cardSubtitle.copyWith(fontSize: 13)),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: m.$2,
                                backgroundColor: AppColors.blackElevated,
                                valueColor: AlwaysStoppedAnimation<Color>(m.$3),
                                minHeight: 7,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('${(m.$2 * 100).toInt()}%',
                              style: AppTextStyles.cardTitle.copyWith(fontSize: 12, color: m.$3)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProteinAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orangeFaint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('🔔', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Protein reminder', style: AppTextStyles.cardTitle.copyWith(color: AppColors.orangeLight)),
                const SizedBox(height: 4),
                Text(
                  'You have ${NutritionData.proteinRemaining}g of protein left to hit your goal. Plan a high-protein dinner.',
                  style: AppTextStyles.cardSubtitle.copyWith(height: 1.5, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Meal Scan Overlay ─────────────────────────────────────────────────────────

  Widget _buildScanOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showScanOverlay = false),
        child: Container(
          color: Colors.black.withOpacity(0.88),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _showScanOverlay = false),
                        child: const Icon(Icons.close_rounded, color: AppColors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Text('Scan Meal', style: AppTextStyles.cardTitle.copyWith(fontSize: 18)),
                    ],
                  ),
                ),
                const Spacer(),
                if (!_scanComplete) ...[
                  // Camera viewport mock
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.orange, width: 2),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.blackSurface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Text('🥣', style: TextStyle(fontSize: 80)),
                          ),
                        ),
                        // Scan line animation
                        AnimatedBuilder(
                          animation: _scanLine,
                          builder: (_, __) {
                            return Positioned(
                              top: _scanLine.value * 270,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppColors.orange.withOpacity(0.8),
                                      AppColors.orange,
                                      AppColors.orange.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Scanning...', style: AppTextStyles.cardSubtitle.copyWith(fontSize: 14)),
                ] else ...[
                  // Scan result
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.blackCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.success.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('🥣', style: TextStyle(fontSize: 32)),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Oats & Protein Shake', style: AppTextStyles.cardTitle),
                                Text('Detected with 94% confidence',
                                    style: AppTextStyles.cardSubtitle.copyWith(color: AppColors.success, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _scanResult('480', 'kcal', AppColors.orange),
                            _scanResult('35g', 'protein', AppColors.orange),
                            _scanResult('58g', 'carbs', AppColors.info),
                            _scanResult('10g', 'fat', AppColors.warning),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OrangeButton(label: 'Log This Meal', onTap: () => setState(() => _showScanOverlay = false)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scanResult(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.statNumber.copyWith(color: color, fontSize: 20)),
        Text(label, style: AppTextStyles.statUnit),
      ],
    );
  }
}
