import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection; // intl also exports TextDirection (bidi); hide it to keep Flutter's enum
import 'package:provider/provider.dart';

import '../models.dart';
import '../providers.dart';
import '../services/usage_service.dart';
import '../widgets/common.dart';

/// Focus tab: screen time (Android) or focus sessions (iOS/web),
/// weekly chart, target setter, coaching message.
class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Focus')),
      body: usage.useAndroidStats
          ? const _AndroidFocusView()
          : const _SessionFocusView(),
    );
  }
}

// ================= Android: real screen-time stats =================

class _AndroidFocusView extends StatelessWidget {
  const _AndroidFocusView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = context.watch<UsageState>();
    final auth = context.watch<AuthState>();
    final target = auth.focusTarget;
    final day = usage.today;
    final screenMinutes = day?.screenMinutes ?? 0;

    if (usage.checkingPermission) {
      return const LoadingView(
          message: 'Checking usage permission…');
    }

    if (!usage.androidPermissionGranted) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.app_blocking_outlined,
                size: 56,
                color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'See your screen time',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Allow usage access so 4cus can track screen time '
              'and coach you toward your goals.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Grant usage access',
              onPressed: () =>
                  usage.requestAndroidPermission(),
              expanded: false,
            ),
          ],
        ),
      );
    }

    final score =
        focusScore(screenMinutes: screenMinutes, targetMinutes: target);

    return RefreshIndicator(
      onRefresh: () => usage.refreshAndroidStats(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _ScoreCard(score: score, screenMinutes: screenMinutes),
          const SizedBox(height: 16),
          _CoachingCard(
            message: coachingMessage(
                screenMinutes: screenMinutes,
                targetMinutes: target),
          ),
          const SizedBox(height: 16),
          _TargetCard(target: target),
          const SizedBox(height: 16),
          const SectionHeader('This week'),
          const SizedBox(height: 8),
          const _WeeklyChartCard(android: true),
          if ((day?.apps ?? []).isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader('Top apps today'),
            const SizedBox(height: 8),
            for (final app in day!.apps.take(5))
              _AppRow(app: app),
          ],
        ],
      ),
    );
  }
}

// ================= iOS/web: focus sessions =================

class _SessionFocusView extends StatelessWidget {
  const _SessionFocusView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = context.watch<UsageState>();
    final auth = context.watch<AuthState>();
    final target = auth.focusTarget;
    final focusMinutes = usage.today?.focusMinutes ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  usage.sessionRunning
                      ? _formatDuration(usage.sessionElapsed)
                      : 'Ready when you are',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                    fontFeatures: const [
                      FontFeature.tabularFigures()
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  usage.sessionRunning
                      ? 'Focus session in progress'
                      : 'Start a session to track focused time',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    if (usage.sessionRunning) ...[
                      OutlinedButton(
                        onPressed: () =>
                            usage.discardFocusSession(),
                        child: const Text('Discard'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () =>
                            usage.stopFocusSession(),
                        child: const Text('Finish'),
                      ),
                    ] else
                      ElevatedButton.icon(
                        onPressed: () =>
                            usage.startFocusSession(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start focus'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CoachingCard(
          message: focusSessionCoachingMessage(
              focusMinutes: focusMinutes,
              targetMinutes: target),
        ),
        const SizedBox(height: 16),
        _TargetCard(target: target),
        const SizedBox(height: 8),
        Text(
          '$focusMinutes of $target focused minutes today',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const SectionHeader('This week'),
        const SizedBox(height: 8),
        const _WeeklyChartCard(android: false),
        const SizedBox(height: 12),
        Text(
          'System screen-time tracking needs Android. On iOS '
          'and web, 4cus tracks the focus sessions you run here.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}

// ================= shared pieces =================

class _ScoreCard extends StatelessWidget {
  final int score;
  final int screenMinutes;

  const _ScoreCard({
    required this.score,
    required this.screenMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: _ScoreRingPainter(
                  fraction: score / 100,
                  color: theme.colorScheme.primary,
                  trackColor: theme
                      .colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(
                    '$score',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(
                            fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Focus score',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(
                            fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$screenMinutes min screen time today',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(
                      color: theme
                          .colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color trackColor;

  _ScoreRingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * fraction.clamp(0.0, 1.0),
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(
          covariant _ScoreRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

class _CoachingCard extends StatelessWidget {
  final String message;

  const _CoachingCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer
          .withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.psychology_outlined,
                color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  final int target;

  const _TargetCard({required this.target});

  Future<void> _edit(BuildContext context) async {
    final controller =
        TextEditingController(text: target.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily target (minutes)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              hintText: 'e.g. 120'),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context)
                .pop(int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result > 0 && context.mounted) {
      await context
          .read<AuthState>()
          .updateFocusTarget(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: const Text('Daily target'),
        subtitle: Text('$target minutes'),
        trailing: TextButton(
          onPressed: () => _edit(context),
          child: const Text('Change'),
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  final UsageApp app;

  const _AppRow({required this.app});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = app.name.split('.').last;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium),
          ),
          Text(
            '${app.minutes} min',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Weekly bar chart drawn with CustomPainter (no chart dependency).
class _WeeklyChartCard extends StatefulWidget {
  final bool android;

  const _WeeklyChartCard({required this.android});

  @override
  State<_WeeklyChartCard> createState() =>
      _WeeklyChartCardState();
}

class _WeeklyChartCardState extends State<_WeeklyChartCard> {
  List<UsageDay>? _days;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days =
        await context.read<UsageState>().last7Days();
    if (mounted) {
      setState(() {
        _days = days;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: LoadingView(),
        ),
      );
    }
    final now = DateTime.now();
    final days = _days ?? const <UsageDay>[];
    final byKey = {for (final d in days) d.dateKey: d};
    final values = List.generate(7, (i) {
      final date = now.subtract(Duration(days: 6 - i));
      final key = dateKeyFromDate(date);
      final day = byKey[key];
      final minutes = widget.android
          ? (day?.screenMinutes ?? 0)
          : (day?.focusMinutes ?? 0);
      return (date: date, minutes: minutes);
    });
    final maxValue =
        values.map((v) => v.minutes).fold<int>(1, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.android
                  ? 'Screen time (min)'
                  : 'Focus minutes',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: CustomPaint(
                painter: _BarChartPainter(
                  values: values,
                  maxValue: maxValue,
                  barColor: theme.colorScheme.primary,
                  labelColor:
                      theme.colorScheme.onSurfaceVariant,
                  todayIndex: 6,
                ),
                child: Container(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<({DateTime date, int minutes})> values;
  final int maxValue;
  final Color barColor;
  final Color labelColor;
  final int todayIndex;

  _BarChartPainter({
    required this.values,
    required this.maxValue,
    required this.barColor,
    required this.labelColor,
    required this.todayIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 22.0;
    const valueHeight = 16.0;
    final chartHeight =
        size.height - labelHeight - valueHeight - 8;
    final slotWidth = size.width / values.length;
    final barWidth = (slotWidth * 0.5).clamp(8.0, 36.0);

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final fraction =
          maxValue <= 0 ? 0.0 : v.minutes / maxValue;
      final barHeight = (chartHeight * fraction)
          .clamp(4.0, chartHeight);
      final x = slotWidth * i + slotWidth / 2;
      final isToday = i == todayIndex;

      final barPaint = Paint()
        ..color = isToday
            ? barColor
            : barColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x - barWidth / 2,
          valueHeight + chartHeight - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, barPaint);

      _drawText(
        canvas,
        '${v.minutes}',
        Offset(x, valueHeight / 2),
        11,
        isToday ? barColor : labelColor,
        bold: isToday,
      );
      _drawText(
        canvas,
        DateFormat('E').format(v.date)[0],
        Offset(x, size.height - labelHeight / 2),
        11,
        labelColor,
        bold: false,
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset center,
      double fontSize, Color color,
      {required bool bold}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight:
              bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.maxValue != maxValue;
}
