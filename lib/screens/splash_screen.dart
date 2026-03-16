import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _contentCtrl;
  late AnimationController _bgCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _taglineOpacity;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _buttonSlide;
  late Animation<double> _bgOpacity;

  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    _bgCtrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _bgOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut),
    );

    _logoCtrl = AnimationController(duration: const Duration(milliseconds: 900), vsync: this);
    _logoScale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );

    _contentCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _taglineSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic),
    );
    _taglineOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: const Interval(0, 0.6)),
    );
    _contentOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: const Interval(0.3, 1.0)),
    );
    _buttonSlide = Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic)),
    );
  }

  void _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 700));
    _contentCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _showOnboarding = true);
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _contentCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: FadeTransition(
        opacity: _bgOpacity,
        child: Stack(
          children: [
            // Background gradient pattern
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter()),
            ),
            // Orange glow at top
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.orange.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    // Logo
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: _buildLogo(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Tagline
                    SlideTransition(
                      position: _taglineSlide,
                      child: FadeTransition(
                        opacity: _taglineOpacity,
                        child: Column(
                          children: [
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'FORGE\n',
                                    style: AppTextStyles.displayHero.copyWith(
                                      color: AppColors.orange,
                                      letterSpacing: 6,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'YOUR LIMITS',
                                    style: AppTextStyles.displayHero.copyWith(
                                      fontSize: 38,
                                      letterSpacing: 4,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            FadeTransition(
                              opacity: _contentOpacity,
                              child: Text(
                                'AI-powered fitness tracking that\nadapts to your body, every day.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.cardSubtitle.copyWith(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: AppColors.grey300,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                    // Buttons
                    if (_showOnboarding)
                      SlideTransition(
                        position: _buttonSlide,
                        child: FadeTransition(
                          opacity: _contentOpacity,
                          child: Column(
                            children: [
                              _buildFeatureRow(),
                              const SizedBox(height: 36),
                              OrangeButton(
                                label: 'Get Started',
                                width: double.infinity,
                                onTap: () => _navigateToHome(context),
                              ),
                              const SizedBox(height: 14),
                              OrangeButton(
                                label: 'Sign In',
                                width: double.infinity,
                                outlined: true,
                                onTap: () => _navigateToHome(context),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Continue with Apple  •  Google',
                                style: AppTextStyles.cardSubtitle.copyWith(
                                  color: AppColors.grey500,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: AppColors.orangeGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withOpacity(0.45),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Text('⚡', style: TextStyle(fontSize: 42)),
      ),
    );
  }

  Widget _buildFeatureRow() {
    final features = [
      (Icons.psychology_rounded, 'AI Coach'),
      (Icons.camera_alt_rounded, 'Meal Scan'),
      (Icons.watch_rounded, 'Wearables'),
      (Icons.people_rounded, 'Challenges'),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: features
          .map((f) => Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.blackCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.blackBorder),
                    ),
                    child: Icon(f.$1, color: AppColors.orange, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(f.$2, style: AppTextStyles.sectionLabel.copyWith(letterSpacing: 0)),
                ],
              ))
          .toList(),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const MainShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}

// Subtle grid painter for background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.blackBorder.withOpacity(0.4)
      ..strokeWidth = 0.5;

    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
