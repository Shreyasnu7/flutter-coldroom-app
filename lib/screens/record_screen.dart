import 'package:flutter/material.dart';

import '../format.dart';
import '../monitor.dart';

/// The food safety record an inspector asks for: every unit's limits, time in range, and each excursion.
class RecordScreen extends StatelessWidget {
  final Monitor monitor;
  const RecordScreen({super.key, required this.monitor});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final rec = monitor.record;
        final theme = Theme.of(context);
        final muted = theme.colorScheme.onSurfaceVariant;
        return Scaffold(
          appBar: AppBar(title: const Text('Food safety record')),
          body: rec == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                  Text('${dayClock(rec.from)} to ${dayClock(rec.to)}', style: TextStyle(color: muted)),
                  const SizedBox(height: 4),
                  Text('Limits from FSANZ Standard 3.2.2: cold food 5 °C or below, frozen food hard frozen.',
                      style: TextStyle(color: muted, fontSize: 12.5)),
                  const SizedBox(height: 12),
                  for (final u in rec.units)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(u.name, style: theme.textTheme.titleMedium)),
                            Text(u.inRangePct == null ? 'no readings' : '${u.inRangePct!.toStringAsFixed(1)}% in range',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: (u.inRangePct ?? 0) >= 99 ? styleFor('ok', theme.brightness).fg : styleFor('warning', theme.brightness).fg)),
                          ]),
                          const SizedBox(height: 4),
                          Text('Limit ${u.limit} · ${u.readings} readings · lowest ${temp(u.min)} · highest ${temp(u.max)}',
                              style: TextStyle(color: muted, fontSize: 12.5)),
                          for (final e in u.excursions)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  '${e.title(monitor.status?.units.where((x) => x.id == u.id).firstOrNull)} from ${clock(e.started)}'
                                  '${e.ended != null ? ' to ${clock(e.ended!)} (${span(e.length!)})' : ', not resolved'}'
                                  '${e.peak != null && e.kind != 'offline' ? ', worst ${temp(e.peak)}' : ''}',
                                  style: TextStyle(color: styleFor(e.kind == 'offline' ? 'offline' : 'alert', theme.brightness).fg)),
                            ),
                        ]),
                      ),
                    ),
                ]),
        );
      },
    );
  }
}
