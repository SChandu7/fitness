import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../models/demo_data.dart';
import '../widgets/common_widgets.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  int _selectedMetric = 0; // 0 = weight, 1 = body fat

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.black,
            floating: true,
            title: Text('Progress', style: AppTextStyles.cardTitle.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildBodySummaryCard(),
                const SizedBox(height: 20),
                _buildCompositionCard(),
                const SizedBox(height: 20),
                _buildTrendChart(),
                const SizedBox(height: 20),
                _buildBodyMetricsGrid(),
                const SizedBox(height: 20),
                _buildRecoveryCard(),
                const SizedBox(height: 20),
                _buildGoalProgress(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodySummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0800), AppColors.blackCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Body Overview', style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700, fontSize: 17)),
                  const SizedBox(height: 2),
                  Text('Last updated: today', style: AppTextStyles.cardSubtitle),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_down_rounded, color: AppColors.success, size: 14),
                    const SizedBox(width: 4),
                    Text('On track', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _bodyStat('${DemoUser.weight}', 'kg', 'Weight', AppColors.orange),
              _bodyDivider(),
              _bodyStat('${DemoUser.bodyFat}%', '', 'Body fat', AppColors.info),
              _bodyDivider(),
              _bodyStat('${BodyMetrics.muscleMass}', 'kg', 'Muscle', AppColors.success),
              _bodyDivider(),
              _bodyStat('${BodyMetrics.bmi}', 'BMI', 'BMI', AppColors.warning),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.arrow_downward_rounded, color: AppColors.success, size: 14),
              const SizedBox(width: 4),
              Text(
                '3.5kg lost since start • 2.8% body fat reduced',
                style: AppTextStyles.cardSubtitle.copyWith(color: AppColors.success, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bodyStat(String val, String unit, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: val,
                  style: AppTextStyles.statNumber.copyWith(fontSize: 20, color: color),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: unit,
                    style: AppTextStyles.statUnit.copyWith(fontSize: 10),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.sectionLabel.copyWith(fontSize: 9)),
        ],
      ),
    );
  }

  Widget _bodyDivider() {
    return Container(width: 1, height: 36, color: AppColors.blackBorder);
  }

  Widget _buildCompositionCard() {
    final segments = [
      ('Muscle', BodyMetrics.muscleMass, AppColors.orange, 81.6),
      ('Fat', DemoUser.weight * DemoUser.bodyFat / 100, AppColors.danger, 18.4),
      ('Bone', BodyMetrics.boneMass, AppColors.info, 4.1),
      ('Water', DemoUser.weight * BodyMetrics.waterPercentage / 100, AppColors.success, 58.4),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Body Composition'),
        const SizedBox(height: 14),
        DarkCard(
          child: Column(
            children: [
              // Stacked bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 20,
                  child: Row(
                    children: [
                      Expanded(flex: 82, child: Container(color: AppColors.orange)),
                      Expanded(flex: 18, child: Container(color: AppColors.danger)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.2,
                children: segments.map((s) {
                  return Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: s.$3, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.$1, style: AppTextStyles.statUnit.copyWith(fontSize: 11)),
                          Text('${s.$2.toStringAsFixed(1)}kg', style: AppTextStyles.cardTitle.copyWith(fontSize: 13, color: s.$3)),
                        ],
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendChart() {
    final data = _selectedMetric == 0
        ? BodyMetrics.weightHistory
        : BodyMetrics.bodyFatHistory;
    final color = _selectedMetric == 0 ? AppColors.orange : AppColors.info;

    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    final minY = (data.reduce((a, b) => a < b ? a : b) - 1);
    final maxY = (data.reduce((a, b) => a > b ? a : b) + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '7-Week Trend'),
        const SizedBox(height: 14),
        DarkCard(
          child: Column(
            children: [
              // Metric selector
              Row(
                children: [
                  _metricTab('Weight', 0),
                  const SizedBox(width: 10),
                  _metricTab('Body Fat %', 1),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: AppColors.blackElevated,
                        getTooltipItems: (spots) => spots.map((s) {
                          return LineTooltipItem(
                            '${s.y.toStringAsFixed(1)}${_selectedMetric == 0 ? 'kg' : '%'}',
                            AppTextStyles.cardTitle.copyWith(color: color, fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) => Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              BodyMetrics.weeks[v.toInt()],
                              style: AppTextStyles.sectionLabel.copyWith(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppColors.blackBorder,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (_, __, ___, i) => FlDotCirclePainter(
                            radius: i == data.length - 1 ? 5 : 3,
                            color: i == data.length - 1 ? color : AppColors.black,
                            strokeColor: color,
                            strokeWidth: 2,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Start: ${data.first.toStringAsFixed(1)}${_selectedMetric == 0 ? 'kg' : '%'}',
                    style: AppTextStyles.statUnit.copyWith(fontSize: 11),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.trending_down_rounded, color: AppColors.success, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${(data.first - data.last).toStringAsFixed(1)}${_selectedMetric == 0 ? 'kg' : '%'} total change',
                        style: AppTextStyles.statUnit.copyWith(fontSize: 11, color: AppColors.success),
                      ),
                    ],
                  ),
                  Text(
                    'Now: ${data.last.toStringAsFixed(1)}${_selectedMetric == 0 ? 'kg' : '%'}',
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 11, color: color),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricTab(String label, int index) {
    final active = _selectedMetric == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMetric = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          gradient: active ? AppColors.orangeGradient : null,
          color: active ? null : AppColors.blackElevated,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.white : AppColors.grey300,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildBodyMetricsGrid() {
    final items = [
      ('Metabolic Age', '${BodyMetrics.metabolicAge}', 'yr', AppColors.orange, Icons.bolt_rounded),
      ('Visceral Fat', '${BodyMetrics.visceralFat}', 'level', AppColors.warning, Icons.favorite_rounded),
      ('Water %', '${BodyMetrics.waterPercentage}%', '', AppColors.info, Icons.water_drop_rounded),
      ('Bone Mass', '${BodyMetrics.boneMass}', 'kg', AppColors.success, Icons.accessibility_new_rounded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Body Metrics'),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: items.map((item) {
            return DarkCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(item.$5, color: item.$4, size: 16),
                      const SizedBox(width: 6),
                      Text(item.$1, style: AppTextStyles.cardSubtitle.copyWith(fontSize: 11)),
                    ],
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: item.$2,
                          style: AppTextStyles.statNumber.copyWith(fontSize: 24, color: item.$4),
                        ),
                        if (item.$3.isNotEmpty)
                          TextSpan(
                            text: ' ${item.$3}',
                            style: AppTextStyles.statUnit,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecoveryCard() {
    return DarkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Recovery & Metabolism', style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Good', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _recoveryRow('Recovery rate', 0.78, AppColors.success),
          const SizedBox(height: 12),
          _recoveryRow('Muscle soreness', 0.35, AppColors.warning),
          const SizedBox(height: 12),
          _recoveryRow('HRV Score', 0.82, AppColors.info),
          const SizedBox(height: 12),
          _recoveryRow('Sleep quality', 0.70, AppColors.orange),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your recovery is strong. You can push hard this week. Consider adding an extra cardio session.',
                    style: AppTextStyles.cardSubtitle.copyWith(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recoveryRow(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: AppTextStyles.cardSubtitle.copyWith(fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: AppColors.blackElevated,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 7,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('${(value * 100).toInt()}%', style: AppTextStyles.cardTitle.copyWith(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildGoalProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Goal Progress'),
        const SizedBox(height: 14),
        DarkCard(
          glowing: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Body Recomposition', style: AppTextStyles.cardTitle),
                      Text('Target: 15% body fat, 66kg muscle mass', style: AppTextStyles.cardSubtitle.copyWith(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _goalBar('Body fat reduction', (21.2 - 18.4) / (21.2 - 15), AppColors.orange, '18.4% → 15%'),
              const SizedBox(height: 12),
              _goalBar('Muscle gain', (63.9 - 60) / (66 - 60), AppColors.success, '63.9 → 66kg'),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Estimated completion in 8–10 weeks',
                    style: AppTextStyles.cardSubtitle.copyWith(fontSize: 12, color: AppColors.warning),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _goalBar(String label, double progress, Color color, String range) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.cardSubtitle.copyWith(fontSize: 12)),
            Text('${(progress * 100).toInt()}% done', style: AppTextStyles.cardTitle.copyWith(fontSize: 12, color: color)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.blackElevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 3),
        Text(range, style: AppTextStyles.statUnit.copyWith(fontSize: 10)),
      ],
    );
  }
}
