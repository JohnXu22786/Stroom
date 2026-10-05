import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'startup_backdrop_painter.dart';
import 'startup_visual_style.dart';

/// A pure-Dart startup screen shown while Stroom performs its startup checks.
///
/// The selected launch style defaults to [StartupVisualStyle.launchDefault].
/// Pass [visualStyle] to show a particular concept, for example in the design
/// gallery or a test.
class StartupPage extends StatefulWidget {
  /// Whether startup checks are still running.
  final bool isWorking;

  /// Current status message to display.
  final String statusMessage;

  /// Progress description (e.g. "2/3" or "50%").
  final String? progressDetail;

  /// Optional fixed appearance; omitted styles use the Mint Glass default.
  final StartupVisualStyle? visualStyle;

  /// Called when the minimum duration has elapsed AND checks are done.
  final VoidCallback? onComplete;

  const StartupPage({
    super.key,
    this.isWorking = true,
    this.statusMessage = '',
    this.progressDetail,
    this.visualStyle,
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
  late StartupVisualStyle _visualStyle;

  @override
  void initState() {
    super.initState();
    _visualStyle = widget.visualStyle ?? StartupVisualStyle.launchDefault;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant StartupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visualStyle != oldWidget.visualStyle) {
      _visualStyle = widget.visualStyle ?? StartupVisualStyle.launchDefault;
    }
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
        backgroundColor: _visualStyle.palette.first,
        body: AnimatedBuilder(
          animation: _gradientController,
          builder: (context, child) {
            final angle = _gradientController.value * 2 * math.pi;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(math.cos(angle), math.sin(angle)),
                  end: Alignment(-math.cos(angle), -math.sin(angle)),
                  colors: _visualStyle.palette,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: StartupBackdropPainter(
                      style: _visualStyle,
                      phase: _gradientController.value,
                    ),
                  ),
                  child!,
                ],
              ),
            );
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildHero(),
                      ),
                    ),
                  ),
                  _buildLoadingSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return switch (_visualStyle) {
      StartupVisualStyle.violetCurrent => _buildVioletHero(),
      StartupVisualStyle.paperDawn => _buildPaperHero(),
      StartupVisualStyle.oceanSignal => _buildOceanHero(),
      StartupVisualStyle.mintGlass => _buildMintHero(),
    };
  }

  Widget _buildVioletHero() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAppIcon(),
        const SizedBox(height: 24),
        _buildBrandName(fontSize: 38, letterSpacing: 2.2),
        const SizedBox(height: 8),
        _buildTagline(),
      ],
    );
  }

  Widget _buildPaperHero() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        decoration: BoxDecoration(
          color: _visualStyle.cardSurface.withValues(alpha: 0.94),
          border: Border.all(color: _visualStyle.cardBorder),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _visualStyle.accent.withValues(alpha: 0.13),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildAppIcon(size: 58),
                const Spacer(),
                Text(
                  'STUDY  /  01',
                  style: TextStyle(
                    color: _visualStyle.secondaryForeground,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _buildBrandName(fontSize: 34, letterSpacing: 0.2),
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 2,
              decoration: BoxDecoration(
                color: _visualStyle.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 13),
            _buildTagline(textAlign: TextAlign.left),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined,
                    size: 15, color: _visualStyle.accent),
                const SizedBox(width: 8),
                Text(
                  '把好奇，慢慢写下来',
                  style: TextStyle(
                    color: _visualStyle.secondaryForeground,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOceanHero() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 216,
          height: 216,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _gradientController,
                builder: (context, child) => CustomPaint(
                  size: const Size(216, 216),
                  painter: StartupSignalOrbitPainter(
                    style: _visualStyle,
                    phase: _gradientController.value,
                  ),
                ),
              ),
              _buildAppIcon(size: 78),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'STROOM  /  ON AIR',
          style: TextStyle(
            color: _visualStyle.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.6,
          ),
        ),
        const SizedBox(height: 10),
        _buildTagline(),
      ],
    );
  }

  Widget _buildMintHero() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _visualStyle.cardSurface.withValues(alpha: 0.24),
          border: Border.all(color: _visualStyle.cardBorder),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _visualStyle.secondaryAccent.withValues(alpha: 0.12),
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'FOCUS FLOW',
                  style: TextStyle(
                    color: _visualStyle.secondaryForeground,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Icon(Icons.more_horiz,
                    color: _visualStyle.secondaryForeground, size: 22),
              ],
            ),
            const SizedBox(height: 22),
            _buildAppIcon(size: 68),
            const SizedBox(height: 18),
            _buildBrandName(fontSize: 34, letterSpacing: 1),
            const SizedBox(height: 7),
            _buildTagline(),
            const SizedBox(height: 22),
            _buildFlowRail(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon({double size = 82}) {
    final radius = _visualStyle == StartupVisualStyle.oceanSignal
        ? size
        : _visualStyle == StartupVisualStyle.paperDawn
            ? 18.0
            : 24.0;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.94 + (_pulseAnimation.value * 0.06),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _visualStyle.cardSurface.withValues(
                alpha:
                    _visualStyle == StartupVisualStyle.paperDawn ? 0.94 : 0.18,
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: _visualStyle.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: _visualStyle.accent.withValues(alpha: 0.18),
                  blurRadius: size * 0.28,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              _visualStyle.icon,
              size: size * 0.5,
              color: _visualStyle.accent,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrandName({
    required double fontSize,
    required double letterSpacing,
  }) {
    return Text(
      'Stroom',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: _visualStyle.foreground,
        letterSpacing: letterSpacing,
        shadows: [
          Shadow(
            color: _visualStyle.palette.first.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildTagline({TextAlign textAlign = TextAlign.center}) {
    return Text(
      '你的学习助理',
      textAlign: textAlign,
      style: TextStyle(
        fontSize: 15,
        color: _visualStyle.secondaryForeground,
        letterSpacing:
            _visualStyle == StartupVisualStyle.violetCurrent ? 1 : 0.4,
      ),
    );
  }

  Widget _buildFlowRail() {
    return Row(
      children: [
        for (var index = 0; index < 3; index++) ...[
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Container(
              width: 7 + (index == 1 ? _pulseAnimation.value * 3 : 0),
              height: 7 + (index == 1 ? _pulseAnimation.value * 3 : 0),
              decoration: BoxDecoration(
                color: index == 1
                    ? _visualStyle.accent
                    : _visualStyle.secondaryAccent.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
            ),
          ),
          if (index < 2)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 7),
                color: _visualStyle.cardBorder,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildLoadingSection() {
    final progressDetail = widget.progressDetail;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: widget.isWorking
              ? CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _visualStyle.accent,
                  backgroundColor:
                      _visualStyle.cardSurface.withValues(alpha: 0.8),
                )
              : Icon(
                  Icons.check_circle,
                  color: _visualStyle.accent,
                  size: 28,
                ),
        ),
        const SizedBox(height: 18),
        if (widget.statusMessage.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _visualStyle.foreground.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ),
        if (progressDetail != null && progressDetail.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            progressDetail,
            style: TextStyle(
              fontSize: 11,
              color: _visualStyle.secondaryForeground.withValues(alpha: 0.8),
              letterSpacing: 1.3,
            ),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }
}
