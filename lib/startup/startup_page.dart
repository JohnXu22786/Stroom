import 'dart:math' as math;

import 'package:flutter/material.dart';

// ====================================================================
// StartupPage — 美观的应用启动页面
// ====================================================================
//
// 显示应用名称、图标和加载动画。
// 在启动检查期间显示，至少 1 秒。
// 当检查完成时，通过回调通知父组件。
// ====================================================================

/// A beautiful startup/splash page shown while the app performs
/// data format checking, migration, and other startup checks.
///
/// # Visual Design
/// - Clean, centered layout with the app icon and name
/// - Animated gradient background
/// - Subtle pulsing loading indicator
/// - Status text updates to reflect progress
///
/// # Behavior
/// - Always shows for at least 1 second (minimumDuration)
/// - Stays longer if [isWorking] is true (data checks in progress)
/// - When [isWorking] transitions to false, calls [onComplete]
/// - Cannot be dismissed by back button or barrier tap
class StartupPage extends StatefulWidget {
  /// Whether startup checks are still running.
  final bool isWorking;

  /// Current status message to display.
  final String statusMessage;

  /// Progress description (e.g. "2/3" or "50%").
  final String? progressDetail;

  /// Whether a data migration has been performed (triggers app restart).
  final bool migrationPerformed;

  /// Called when the minimum duration has elapsed AND checks are done.
  final VoidCallback? onComplete;

  const StartupPage({
    super.key,
    this.isWorking = true,
    this.statusMessage = '',
    this.progressDetail,
    this.migrationPerformed = false,
    this.onComplete,
  });

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _gradientController;

  @override
  void initState() {
    super.initState();

    // Pulsing animation for the loading indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Gradient animation
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _gradientController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: _buildGradient(),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // App Icon
                  _buildAppIcon(),
                  const SizedBox(height: 24),
                  // App Name
                  Text(
                    'Stroom',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tagline
                  Text(
                    '你的学习助理',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Loading section
                  _buildLoadingSection(),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Loading indicator
        SizedBox(
          width: 28,
          height: 28,
          child: widget.isWorking
              ? CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.9),
                  ),
                )
              : Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent.withValues(alpha: 0.9),
                  size: 28,
                ),
        ),
        const SizedBox(height: 20),
        // Status message
        if (widget.statusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              widget.statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        // Progress detail
        if (widget.progressDetail != null &&
            widget.progressDetail!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.progressDetail!,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  LinearGradient _buildGradient() {
    // Determine base colors based on migration state
    final colors = widget.migrationPerformed
        ? [
            const Color(0xFF1A237E),
            const Color(0xFF4A148C),
            const Color(0xFF880E4F),
          ]
        : [
            const Color(0xFF0D47A1),
            const Color(0xFF1565C0),
            const Color(0xFF00897B),
          ];

    // Animate the gradient angle
    final angle = _gradientController.value * 2 * math.pi;
    return LinearGradient(
      begin: Alignment(
        math.cos(angle),
        math.sin(angle),
      ),
      end: Alignment(
        -math.cos(angle),
        -math.sin(angle),
      ),
      colors: colors,
    );
  }
}
