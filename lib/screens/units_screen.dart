import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../monitor.dart';
import '../widgets/temp_chart.dart';
import 'record_screen.dart';
import 'settings_screen.dart';
import 'unit_screen.dart';

class UnitsScreen extends StatelessWidget {
  final Monitor monitor;
  const UnitsScreen({super.key, required this.monitor});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final s = monitor.status;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Cold storage'),
            actions: [
              IconButton(
                tooltip: 'Food safety record',
                icon: const Icon(Icons.fact_check_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordScreen(monitor: monitor))),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(monitor: monitor))),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: monitor.refresh,
            child: s == null
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(child: monitor.error != null ? _Problem(monitor.error!) : const CircularProgressIndicator()),
                  ])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _Freshness(monitor: monitor),
                      for (final u in s.needingAttention) _AttentionBanner(unit: u, monitor: monitor),
                      for (final u in s.units) _UnitCard(unit: u, monitor: monitor),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _Problem extends StatelessWidget {
  final String text;
  const _Problem(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Pull down to try again, or check the address in Settings.',
              textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
}

class _Freshness extends StatelessWidget {
  final Monitor monitor;
  const _Freshness({required this.monitor});
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final when = monitor.lastOk == null ? '' : 'Updated ${ago(DateTime.now().difference(monitor.lastOk!).inSeconds.toDouble())}';
    if (monitor.error != null && monitor.status != null) {
      final st = styleFor('warning', Theme.of(context).brightness);
      return Card(
        color: st.bg,
        elevation: 0,
        child: ListTile(
          leading: Icon(Icons.cloud_off_outlined, color: st.fg),
          title: Text(monitor.error!, style: TextStyle(color: st.fg)),
          subtitle: Text('Showing what we had. $when', style: TextStyle(color: st.fg)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Text('${monitor.source.label} · $when', style: TextStyle(color: muted, fontSize: 12.5)),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  final Unit unit;
  final Monitor monitor;
  const _AttentionBanner({required this.unit, required this.monitor});
  @override
  Widget build(BuildContext context) {
    final st = styleFor(unit.state, Theme.of(context).brightness);
    final since = monitor.secondsSince(unit.alertSince ?? unit.lastSeen);
    final what = unit.state == 'offline'
        ? 'No readings for ${ago(since).replaceAll(' ago', '')}. Check the sensor battery and Wi-Fi, and check the unit by hand.'
        : '${temp(unit.temp)} and out of range for ${ago(since).replaceAll(' ago', '')}. Check the door and the food inside.';
    return Card(
      color: st.bg,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(st.icon, color: st.fg),
        title: Text(unit.name, style: TextStyle(color: st.fg, fontWeight: FontWeight.w600)),
        subtitle: Text(what, style: TextStyle(color: st.fg)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnitScreen(monitor: monitor, unitId: unit.id))),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final Unit unit;
  final Monitor monitor;
  const _UnitCard({required this.unit, required this.monitor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = styleFor(unit.state, theme.brightness);
    final points = monitor.history[unit.id] ?? const [];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnitScreen(monitor: monitor, unitId: unit.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(unit.name, style: theme.textTheme.titleMedium)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(st.icon, size: 14, color: st.fg),
                  const SizedBox(width: 4),
                  Text(st.label, style: TextStyle(color: st.fg, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(temp(unit.temp),
                  style: theme.textTheme.headlineMedium!.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()], color: unit.state == 'offline' ? theme.colorScheme.onSurfaceVariant : null)),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('safe ${unit.limitText} · ${ago(monitor.secondsSince(unit.lastSeen))}',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5)),
                ),
              ),
            ]),
            if (points.length > 1) ...[
              const SizedBox(height: 8),
              SizedBox(height: 44, child: TempChart(points: points, unit: unit, compact: true)),
            ],
          ]),
        ),
      ),
    );
  }
}
