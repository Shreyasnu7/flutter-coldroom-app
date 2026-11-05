import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';

/// Temperature over time with the safe band shaded and anything outside it drawn in the alarm colour.
class TempChart extends StatelessWidget {
  final List<Point> points;
  final Unit unit;
  final bool compact;
  const TempChart({super.key, required this.points, required this.unit, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${unit.name} temperature over the last 24 hours',
      child: CustomPaint(
        painter: _ChartPainter(points, unit, compact, scheme, styleFor('alert', Theme.of(context).brightness).fg,
            Theme.of(context).textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant)),
        size: Size.infinite,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<Point> points;
  final Unit unit;
  final bool compact;
  final ColorScheme scheme;
  final Color alarm;
  final TextStyle label;
  _ChartPainter(this.points, this.unit, this.compact, this.scheme, this.alarm, this.label);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final left = compact ? 0.0 : 34.0, bottom = compact ? 0.0 : 18.0;
    final w = size.width - left, h = size.height - bottom;
    final t0 = points.first.t, t1 = points.last.t;
    final temps = points.map((p) => p.temp).toList();
    var lo = [temps.reduce(math.min), unit.isFreezer ? unit.max : unit.min].reduce(math.min);
    var hi = [points.map((p) => p.hi).reduce(math.max), unit.max].reduce(math.max);
    final pad = math.max((hi - lo) * 0.12, 0.8);
    lo -= pad;
    hi += pad;
    double x(double t) => left + (t - t0) / (t1 - t0) * w;
    double y(double v) => (hi - v) / (hi - lo) * h;

    // the safe band
    final bandTop = y(unit.max), bandBottom = unit.isFreezer ? h : y(unit.min);
    canvas.drawRect(Rect.fromLTRB(left, bandTop, size.width, bandBottom), Paint()..color = scheme.primary.withOpacity(0.08));
    final limit = Paint()
      ..color = scheme.primary.withOpacity(0.5)
      ..strokeWidth = 1;
    _dashed(canvas, Offset(left, bandTop), Offset(size.width, bandTop), limit);
    if (!unit.isFreezer) _dashed(canvas, Offset(left, bandBottom), Offset(size.width, bandBottom), limit);

    if (!compact) {
      final step = (hi - lo) > 12 ? 5.0 : (hi - lo) > 5 ? 2.0 : 1.0;
      for (var v = (lo / step).ceil() * step; v <= hi; v += step) {
        canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), Paint()..color = scheme.outlineVariant.withOpacity(0.35));
        _text(canvas, '${v.toStringAsFixed(0)}°', Offset(0, y(v) - 7));
      }
      for (var k = 0; k <= 4; k++) {
        final t = t0 + (t1 - t0) * k / 4;
        final s = clock(t);
        _text(canvas, s, Offset((x(t) - 18).clamp(left, size.width - 40), h + 4));
      }
    }

    // the line, split so out-of-range stretches are drawn in the alarm colour; gaps over 15 min are left as gaps
    final ok = Paint()
      ..color = scheme.primary
      ..strokeWidth = compact ? 1.6 : 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final bad = Paint()
      ..color = alarm
      ..strokeWidth = compact ? 1.8 : 2.4
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (b.t - a.t > 900) continue;
      final out = !unit.inRange(a.temp) || !unit.inRange(b.temp);
      canvas.drawLine(Offset(x(a.t), y(a.temp)), Offset(x(b.t), y(b.temp)), out ? bad : ok);
    }
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    final len = (b - a).distance;
    for (var d = 0.0; d < len; d += 9) {
      c.drawLine(a + (b - a) * (d / len), a + (b - a) * (math.min(d + 5, len) / len), p);
    }
  }

  void _text(Canvas c, String s, Offset at) {
    final tp = TextPainter(text: TextSpan(text: s, style: label), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.points != points || old.unit != unit || old.scheme != scheme;
}
