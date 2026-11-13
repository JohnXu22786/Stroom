part of 'home_page.dart';

/// The centered dot and localized label shown in one home status item.
class HomeStatusLabel extends StatelessWidget {
  const HomeStatusLabel({
    super.key,
    required this.label,
    required this.dotColor,
  });

  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reveals the full label when it cannot fit in its home-card text slot.
/// The full value remains available as one accessible label while the visual
/// copy travels in both directions with a two-second pause at each edge.
class _HomeOverflowMarquee extends StatefulWidget {
  const _HomeOverflowMarquee({
    required this.text,
    required this.style,
    this.textAlign,
    this.speed = 24,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
    this.marqueeTextAlign,
    this.centerInViewport = false,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final double speed;
  final int? maxLines;
  final TextOverflow overflow;
  final bool softWrap;
  final TextAlign? marqueeTextAlign;
  final bool centerInViewport;

  @override
  State<_HomeOverflowMarquee> createState() => _HomeOverflowMarqueeState();
}

class _HomeOverflowMarqueeState extends State<_HomeOverflowMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  Animation<double> _position = const AlwaysStoppedAnimation(0);
  double _overflow = 0;
  double _textWidth = 0;
  double _textHeight = 0;
  double _measuredWidth = 0;
  TextDirection? _measuredDirection;
  TextScaler? _measuredScaler;
  TextStyle? _measuredStyle;
  Locale? _measuredLocale;
  bool _isAnimating = false;

  @override
  void didUpdateWidget(covariant _HomeOverflowMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.speed != widget.speed ||
        oldWidget.maxLines != widget.maxLines ||
        oldWidget.overflow != widget.overflow ||
        oldWidget.softWrap != widget.softWrap ||
        oldWidget.textAlign != widget.textAlign ||
        oldWidget.marqueeTextAlign != widget.marqueeTextAlign ||
        oldWidget.centerInViewport != widget.centerInViewport) {
      _measuredWidth = 0;
      _measuredDirection = null;
      _measuredScaler = null;
      _measuredStyle = null;
      _measuredLocale = null;
      _controller.stop();
      _controller.value = 0;
      _isAnimating = false;
    }
  }

  void _measure(
    double width,
    TextDirection direction,
    TextScaler scaler,
    TextStyle textStyle,
    Locale? locale,
    bool allowMotion,
  ) {
    if (width != _measuredWidth ||
        direction != _measuredDirection ||
        scaler != _measuredScaler ||
        textStyle != _measuredStyle ||
        locale != _measuredLocale) {
      _measuredWidth = width;
      _measuredDirection = direction;
      _measuredScaler = scaler;
      _measuredStyle = textStyle;
      _measuredLocale = locale;
      final measurement = _measureText(
        width,
        direction,
        scaler,
        textStyle,
        locale,
      );
      final nextOverflow = measurement.overflow;
      _textWidth = measurement.textWidth;
      _textHeight = measurement.textHeight;
      if (nextOverflow != _overflow) {
        _overflow = nextOverflow;
        _controller.stop();
        _controller.value = 0;
        _isAnimating = false;
      }
    }

    final shouldAnimate = _overflow > 0 && allowMotion;
    if (shouldAnimate && !_isAnimating) {
      final travelMilliseconds =
          math.max(1, (_overflow / widget.speed * 1000).round()).toInt();
      _controller.duration = Duration(
        milliseconds: travelMilliseconds * 2 + 4000,
      );
      _position = TweenSequence<double>([
        TweenSequenceItem(tween: ConstantTween(0), weight: 2000),
        TweenSequenceItem(
          tween: Tween(begin: 0, end: 1),
          weight: travelMilliseconds.toDouble(),
        ),
        TweenSequenceItem(tween: ConstantTween(1), weight: 2000),
        TweenSequenceItem(
          tween: Tween(begin: 1, end: 0),
          weight: travelMilliseconds.toDouble(),
        ),
      ]).animate(_controller);
      _controller.repeat();
      _isAnimating = true;
    } else if (!shouldAnimate && _isAnimating) {
      _controller.stop();
      _isAnimating = false;
    }
  }

  ({double overflow, double textWidth, double textHeight}) _measureText(
    double width,
    TextDirection direction,
    TextScaler scaler,
    TextStyle textStyle,
    Locale? locale,
  ) {
    if (width <= 0 || widget.maxLines == null) {
      return (overflow: 0, textWidth: 0, textHeight: 0);
    }
    final text = TextSpan(text: widget.text, style: textStyle);
    final constrainedPainter = TextPainter(
      text: text,
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
      textAlign: widget.textAlign ?? TextAlign.start,
      maxLines: widget.maxLines,
      ellipsis: widget.overflow == TextOverflow.ellipsis ? '…' : null,
    )..layout(maxWidth: width);
    if (!constrainedPainter.didExceedMaxLines) {
      return (overflow: 0, textWidth: 0, textHeight: 0);
    }

    final naturalPainter = TextPainter(
      text: text,
      textDirection: direction,
      textScaler: scaler,
      locale: locale,
      textAlign: widget.textAlign ?? TextAlign.start,
      maxLines: widget.maxLines,
    )..layout();
    final textWidth = naturalPainter.width;
    return (
      overflow: (textWidth - width).clamp(0.0, double.infinity).toDouble(),
      textWidth: textWidth,
      textHeight: naturalPainter.height,
    );
  }

  Widget _buildOriginalText() => Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        softWrap: widget.softWrap,
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final textStyle = DefaultTextStyle.of(context).style.merge(widget.style);
    final locale = Localizations.maybeLocaleOf(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tickerEnabled = TickerMode.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width.isFinite) {
          _measure(
            width,
            direction,
            scaler,
            textStyle,
            locale,
            !reduceMotion && tickerEnabled,
          );
        }
        final isMoving = _overflow > 0 && !reduceMotion && tickerEnabled;
        if (!isMoving) return _buildOriginalText();

        return Semantics(
          label: widget.text,
          child: SizedBox(
            width: width,
            child: ClipRect(
              child: SizedBox(
                height: _textHeight,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final position = _position.value;
                    final textOffset = direction == TextDirection.ltr
                        ? -_overflow * position
                        : -_overflow * (1 - position);
                    return ExcludeSemantics(
                      child: CustomPaint(
                        size: Size(width, _textHeight),
                        painter: _HomeOverflowTextPainter(
                          text: widget.text,
                          style: textStyle,
                          textDirection: direction,
                          textScaler: scaler,
                          locale: locale,
                          textAlign: widget.marqueeTextAlign ??
                              widget.textAlign ??
                              TextAlign.start,
                          textWidth: _textWidth,
                          textOffset: textOffset,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeOverflowTextPainter extends CustomPainter {
  _HomeOverflowTextPainter({
    required this.text,
    required this.style,
    required this.textDirection,
    required this.textScaler,
    required this.locale,
    required this.textAlign,
    required this.textWidth,
    required this.textOffset,
  });

  final String text;
  final TextStyle style;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final TextAlign textAlign;
  final double textWidth;
  final double textOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      textAlign: textAlign,
      maxLines: 1,
    )..layout(maxWidth: textWidth);
    painter.paint(canvas, Offset(textOffset, 0));
  }

  @override
  bool shouldRepaint(covariant _HomeOverflowTextPainter oldDelegate) =>
      text != oldDelegate.text ||
      style != oldDelegate.style ||
      textDirection != oldDelegate.textDirection ||
      textScaler != oldDelegate.textScaler ||
      locale != oldDelegate.locale ||
      textAlign != oldDelegate.textAlign ||
      textWidth != oldDelegate.textWidth ||
      textOffset != oldDelegate.textOffset;
}

/// Aggregated task counts for the home status card.
///
/// Watches all three task providers plus flow executions and computes the
/// counts in one place: flow sub-tasks are excluded (they render inside
/// their flow card in the unified list) and each flow execution counts
/// once by its own status. All state is read fresh inside the provider
/// body — no closure-capture staleness. The result is a value-comparable
/// record, so the home page only rebuilds when a count actually changes,
/// not on every intermediate step update (e.g. updateStep running →
/// running on a different step index), keeping the GUI responsive during
/// CPU-bound extraction pipelines.
final homeStatusCountsProvider =
    Provider<({int inProgress, int completed, int failed})>((ref) {
  final bgTasks = ref.watch(backgroundTasksProvider);
  final catcatchTasks = ref.watch(catcatchTasksProvider);
  final synthesisTasks = ref.watch(taskListProvider);
  final flowExecutions = ref.watch(taskFlowExecutionsProvider);

  final flowSubTaskIds = <String>{
    for (final e in flowExecutions)
      for (final st in e.subTasks) st.subTaskId,
  };

  int inProgress = 0, completed = 0, failed = 0;

  void addStatus(String statusName) {
    if (statusName == 'running' ||
        statusName == 'paused' ||
        statusName == 'waiting') {
      inProgress++;
    } else if (statusName == 'completed') {
      completed++;
    } else if (statusName == 'failed') {
      failed++;
    }
  }

  void addTaskIfStandalone(String id, String statusName) {
    if (flowSubTaskIds.contains(id)) return;
    addStatus(statusName);
  }

  for (final t in bgTasks) {
    addTaskIfStandalone(t.id, t.status.name);
  }
  for (final t in catcatchTasks) {
    addTaskIfStandalone(t.id, t.status.name);
  }
  for (final t in synthesisTasks) {
    addTaskIfStandalone(t.id, t.status.name);
  }
  // Each flow execution is exactly one card in the unified task list —
  // count it once, matching what the user sees there.
  for (final e in flowExecutions) {
    addStatus(e.status.name);
  }

  return (inProgress: inProgress, completed: completed, failed: failed);
});

extension _HomePageHomeContentExt on _HomePageState {
  /// 构建模块化首页内容
  Widget _buildHomeContent() {
    final cs = Theme.of(context).colorScheme;
    final counts = ref.watch(homeStatusCountsProvider);
    final inProgressCount = counts.inProgress;
    final completedCount = counts.completed;
    final failedCount = counts.failed;

    return SafeArea(
      top: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        // Whole content scrolls so short/landscape screens don't overflow
        // (the module grid is shrink-wrapped — a fixed handful of cards,
        // no perf concern).
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — no notification button (replaced by status card)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 24, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.homeWelcome,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.homeChooseModule,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              // Status card — shows task counts by status
              _buildStatusCard(
                context,
                inProgressCount,
                completedCount,
                failedCount,
              ),
              const SizedBox(height: 16),
              // Full-width task flow entry below recent tasks
              _buildTaskFlowCard(context),
              const SizedBox(height: 16),
              // Module grid — a Wrap (NOT a GridView): a scrollable grid
              // registers its own drag recognizer even with
              // NeverScrollableScrollPhysics and swallows page swipes that
              // start on it (deepest recognizer wins the gesture arena).
              // Fixed handful of cards — no perf concern.
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  // Same column math as the old
                  // SliverGridDelegateWithMaxCrossAxisExtent(180, spacing 12):
                  // ceil(width / (180 + 12)) — floor(width/180) would give
                  // fewer, much wider columns on phones.
                  final cols = math.max(1, (width / 192).ceil());
                  final cardWidth = (width - (cols - 1) * 12) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final card in _moduleCards())
                        SizedBox(
                          width: cardWidth,
                          height: cardWidth / 1.2,
                          child: card,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _moduleCards() {
    return [
      _buildModuleCard(
        icon: Icons.text_snippet,
        label: 'OCR',
        subtitle: AppLocalizations.of(context)!.homeOcrSubtitle,
        color: Colors.teal,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OcrPage()),
          );
        },
      ),
      _buildModuleCard(
        icon: Icons.multitrack_audio,
        label: AppLocalizations.of(context)!.homeAsrTitle,
        subtitle: AppLocalizations.of(context)!.homeAsrSubtitle,
        color: Colors.deepPurple,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AsrPage()),
          );
        },
      ),
      _buildModuleCard(
        icon: Icons.language,
        label: AppLocalizations.of(context)!.homeWebDownloadTitle,
        subtitle: AppLocalizations.of(context)!.homeWebDownloadSubtitle,
        subtitleSpeed: 24,
        color: Colors.purple,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CatCatchPage()),
          );
        },
      ),
      _buildModuleCard(
        icon: Icons.music_note,
        label: AppLocalizations.of(context)!.homeAudioSeparationTitle,
        subtitle: AppLocalizations.of(context)!.homeAudioSeparationSubtitle,
        color: Colors.indigo,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AudioSeparationPage()),
          );
        },
      ),
      _buildModuleCard(
        icon: Icons.record_voice_over,
        label: AppLocalizations.of(context)!.homeTtsTitle,
        subtitle: AppLocalizations.of(context)!.homeTtsSubtitle,
        color: Colors.cyan,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TTSCreatePage()),
          );
        },
      ),
      _buildModuleCard(
        icon: Icons.account_tree,
        label: AppLocalizations.of(context)!.homeChartsTitle,
        subtitle: AppLocalizations.of(context)!.homeChartsSubtitle,
        color: Colors.orange,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MermaidChartPage()),
          );
        },
      ),
      _buildModuleCard(
        icon: Icons.functions,
        label: AppLocalizations.of(context)!.homeMathTitle,
        subtitle: AppLocalizations.of(context)!.homeMathSubtitle,
        color: Colors.blue,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MathDrawingPage()),
          );
        },
      ),
      _buildModuleCard(
        icon: Icons.auto_stories,
        label: AppLocalizations.of(context)!.homeAnkiTitle,
        subtitle: AppLocalizations.of(context)!.homeAnkiSubtitle,
        // blueGrey: 与 OCR 的 teal 区分，同时贴近 Anki 品牌蓝
        color: Colors.blueGrey,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnkiDroidPage()),
          );
        },
      ),
    ];
  }

  /// 构建模块卡片
  Widget _buildModuleCard({
    required IconData icon,
    required String label,
    required String subtitle,
    double subtitleSpeed = 24,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 4),
              _HomeOverflowMarquee(
                text: label,
                centerInViewport: true,
                marqueeTextAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              _HomeOverflowMarquee(
                text: subtitle,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
                speed: subtitleSpeed,
                centerInViewport: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-width entry to the task flow system, shown below the recent
  /// tasks status card (original design: full-width card with flow count).
  Widget _buildTaskFlowCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final taskFlows = ref.watch(taskFlowListProvider);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskFlowListPage()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.account_tree, size: 22, color: cs.tertiary),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeOverflowMarquee(
                      text: AppLocalizations.of(context)!.homeTaskFlowTitle,
                      maxLines: null,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _HomeOverflowMarquee(
                      maxLines: null,
                      overflow: TextOverflow.clip,
                      text: taskFlows.isEmpty
                          ? AppLocalizations.of(context)!.homeTaskFlowEmpty
                          : AppLocalizations.of(context)!
                              .homeTaskFlowManage(taskFlows.length),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Add button (chevron always — the home navigation test
              // asserts no standalone plus icon on the home page)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.chevron_right, size: 18, color: cs.tertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建扁平圆角框状态卡片
  Widget _buildStatusCard(
    BuildContext context,
    int inProgressCount,
    int completedCount,
    int failedCount,
  ) {
    final cs = Theme.of(context).colorScheme;

    Widget _statusItem({
      required int count,
      required String label,
      required Color dotColor,
      required int tabIndex,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UnifiedTaskListPage(initialTab: tabIndex),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                HomeStatusLabel(label: label, dotColor: dotColor),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            // Header row: "最近任务" on left, "查看全部 >" on right
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 6),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.homeRecentTasks,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const UnifiedTaskListPage(initialTab: 0),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.homeViewAll,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 1),
                          Text(
                            '>',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Status items row — 等分三列
            Row(
              children: [
                _statusItem(
                  count: inProgressCount,
                  label: AppLocalizations.of(context)!.statusInProgress,
                  dotColor: const Color(0xFFFF9800), // orange
                  tabIndex: 1,
                ),
                _statusItem(
                  count: completedCount,
                  label: AppLocalizations.of(context)!.statusCompleted,
                  dotColor: const Color(0xFF4CAF50), // green
                  tabIndex: 2,
                ),
                _statusItem(
                  count: failedCount,
                  label: AppLocalizations.of(context)!.statusFailed,
                  dotColor: const Color(0xFFF44336), // red
                  tabIndex: 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
