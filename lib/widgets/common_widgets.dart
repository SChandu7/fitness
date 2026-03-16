import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Orange glowing button
class OrangeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double? width;
  final bool outlined;
  final IconData? icon;

  const OrangeButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.outlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: 52,
        decoration: BoxDecoration(
          gradient: outlined ? null : AppColors.orangeGradient,
          border: Border.all(
            color: AppColors.orange,
            width: outlined ? 1.5 : 0,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: AppColors.orange.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppTextStyles.buttonText),
          ],
        ),
      ),
    );
  }
}

/// Dark card with optional orange border glow
class DarkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool glowing;
  final VoidCallback? onTap;
  final double borderRadius;

  const DarkCard({
    super.key,
    required this.child,
    this.padding,
    this.glowing = false,
    this.onTap,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: glowing ? AppColors.orange.withOpacity(0.4) : AppColors.blackBorder,
            width: 1,
          ),
          boxShadow: glowing
              ? [
                  BoxShadow(
                    color: AppColors.orange.withOpacity(0.08),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

/// Section header row with optional action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: AppTextStyles.orangeAccent),
          ),
      ],
    );
  }
}

/// Animated macro pill
class MacroPill extends StatelessWidget {
  final String label;
  final int consumed;
  final int total;
  final Color color;

  const MacroPill({
    super.key,
    required this.label,
    required this.consumed,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (consumed / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.cardSubtitle),
            Text('${consumed}g', style: AppTextStyles.cardTitle.copyWith(fontSize: 13, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.blackElevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 4),
        Text('${total - consumed}g left', style: AppTextStyles.statUnit.copyWith(fontSize: 11)),
      ],
    );
  }
}

/// Streak flame badge
class StreakBadge extends StatefulWidget {
  final int count;

  const StreakBadge({super.key, required this.count});

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.orangeGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppColors.orange.withOpacity(0.4), blurRadius: 12, spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              '${widget.count} day streak',
              style: AppTextStyles.labelLarge.copyWith(fontSize: 12, color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact stat box
class StatBox extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color? valueColor;

  const StatBox({
    super.key,
    required this.value,
    required this.unit,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: AppTextStyles.statNumber.copyWith(
                  fontSize: 26,
                  color: valueColor ?? AppColors.white,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: AppTextStyles.statUnit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.sectionLabel),
      ],
    );
  }
}

/// Custom bottom navigation bar
class ForgeBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ForgeBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.fitness_center_rounded, 'Workout'),
      (Icons.restaurant_rounded, 'Nutrition'),
      (Icons.bar_chart_rounded, 'Progress'),
      (Icons.people_rounded, 'Social'),
    ];

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: AppColors.blackCard,
        border: Border(top: BorderSide(color: AppColors.blackBorder, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final isActive = i == currentIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.orangeGlow : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      items[i].$1,
                      color: isActive ? AppColors.orange : AppColors.grey500,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].$2,
                    style: TextStyle(
                      color: isActive ? AppColors.orange : AppColors.grey500,
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
