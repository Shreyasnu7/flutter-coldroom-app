// Runs against a real monitor when MONITOR_URL is set (python backend/main.py in iot-dashboard, then simulate.py).
import 'dart:io';

import 'package:coldroom_app/api.dart';
import 'package:coldroom_app/monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final url = Platform.environment['MONITOR_URL'];
  test('reads status, history and the record from a running monitor', () async {
    final m = Monitor(ServerSource(url!));
    await m.refresh();
    expect(m.error, isNull);
    expect(m.status!.units, hasLength(4));
    expect(m.history.values.every((h) => h.isNotEmpty), isTrue);
    expect(m.record!.units.map((u) => u.readings).reduce((a, b) => a + b), greaterThan(1000));
    // ignore: avoid_print
    print('live: ${m.status!.units.map((u) => '${u.name} ${u.temp} ${u.state}').join(', ')}');
  }, skip: url == null ? 'set MONITOR_URL to run against a live monitor' : false);
}
