import 'package:flutter/material.dart';

import '../format.dart';
import '../monitor.dart';
import '../widgets/temp_chart.dart';

class UnitScreen extends StatelessWidget {
  final Monitor monitor;
  final String unitId;
  const UnitScreen({super.key, required this.monitor, required this.unitId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final unit = monitor.status!.units.firstWhere((u) => u.id == unitId);
        final theme = Theme.of(context);
        final st = styleFor(unit.state, theme.brightness);
        final rec = monitor.recordFor(unitId);
        final points = monitor.history[unitId] ?? const [];
        final muted = theme.colorScheme.onSurfaceVariant;
        return Scaffold(
          appBar: AppBar(title: Text(unit.name)),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(temp(unit.temp), style: theme.textTheme.displaySmall!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [Icon(st.icon, color: st.fg, size: 18), const SizedBox(width: 4), Text(st.label, style: TextStyle(color: st.fg))]),
              ),
            ]),
            Text('Safe range ${unit.limitText} · last reading ${ago(monitor.secondsSince(unit.lastSeen))}'
                '${unit.humidity != null ? ' · ${unit.humidity!.toStringAsFixed(0)}% RH' : ''}', style: TextStyle(color: muted)),
            const SizedBox(height: 18),
            Text('Last 24 hours', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(height: 220, child: points.length > 1 ? TempChart(points: points, unit: unit) : Center(child: Text('No history yet', style: TextStyle(color: muted)))),
            const SizedBox(height: 6),
            Text('Shaded: the safe range. Red: out of range. Gaps: no readings.', style: TextStyle(color: muted, fontSize: 12)),
            if (rec != null) ...[
              const SizedBox(height: 18),
              Row(children: [
                _Stat('In range', rec.inRangePct == null ? '–' : '${rec.inRangePct!.toStringAsFixed(1)}%'),
                _Stat('Lowest', temp(rec.min)),
                _Stat('Highest', temp(rec.max)),
                _Stat('Readings', '${rec.readings}'),
              ]),
              const SizedBox(height: 18),
              Text('Excursions', style: theme.textTheme.titleSmall),
              if (rec.excursions.isEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('None in the last 24 hours.', style: TextStyle(color: muted))),
              for (final e in rec.excursions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(e.kind == 'offline' ? Icons.sensors_off_outlined : Icons.thermostat, color: styleFor(e.kind == 'offline' ? 'offline' : 'alert', theme.brightness).fg),
                  title: Text(e.title(unit)),
                  subtitle: Text('${dayClock(e.started)}${e.length != null ? ' for ${span(e.length!)}' : ', still going'}'
                      '${e.peak != null && e.kind != 'offline' ? ' · worst ${temp(e.peak)}' : ''}'),
                ),
            ],
          ]),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ]),
      );
}
