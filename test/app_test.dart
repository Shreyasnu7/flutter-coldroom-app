import 'dart:convert';
import 'dart:io';

import 'package:coldroom_app/api.dart';
import 'package:coldroom_app/main.dart';
import 'package:coldroom_app/models.dart';
import 'package:coldroom_app/monitor.dart';
import 'package:coldroom_app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String> fromDisk(String path) async => File(path).readAsString();
DemoSource demo() => DemoSource(load: fromDisk);

void main() {
  test('the captured demo day parses into what the screens need', () async {
    final s = await demo().status();
    expect(s.units.map((u) => u.name), ['Kitchen fridge', 'Display fridge', 'Chest freezer', 'Cool room']);
    expect(s.needingAttention.single.state, 'offline');
    final freezer = s.units[2];
    expect(freezer.isFreezer, isTrue);
    expect(freezer.limitText, '-15 °C or colder');
    final rec = await demo().record();
    final display = rec.units.firstWhere((u) => u.id == 'fridge-display');
    expect(display.excursions.single.kind, 'temperature');
    expect(display.excursions.single.title(s.units[1]), 'Too warm');
    expect(display.excursions.single.peak, greaterThan(5));
    expect(display.excursions.single.length!.inMinutes, greaterThan(10));
    expect(display.inRangePct, lessThan(100));
    expect((await demo().history('freezer')).length, greaterThan(200));
  });

  test('server errors become messages a person can act on', () async {
    final ok = ServerSource('http://monitor.local:8006/', client: MockClient((r) async {
      expect(r.url.path, '/api/status');
      return http.Response(await File('assets/demo/status.json').readAsString(), 200);
    }));
    expect((await ok.status()).units, hasLength(4));
    final down = ServerSource('http://monitor.local:8006', client: MockClient((r) async => http.Response('nope', 502)));
    await expectLater(down.status(), throwsA(isA<ApiError>().having((e) => e.message, 'message', contains('502'))));
    final gone = ServerSource('http://monitor.local:8006', client: MockClient((r) async => throw const SocketException('no route')));
    await expectLater(gone.status(), throwsA(isA<ApiError>().having((e) => e.message, 'message', contains("Can't reach"))));
    final history = ServerSource('http://monitor.local:8006', client: MockClient((r) async {
      expect(r.url.toString(), 'http://monitor.local:8006/api/history/freezer?hours=24');
      return http.Response(jsonEncode([{'t': 1, 'temp': -18.2, 'hi': -17.9}]), 200);
    }));
    expect((await history.history('freezer')).single.temp, -18.2);
  });

  test('when the server drops out, the last data stays and is marked stale', () async {
    var now = DateTime(2026, 10, 29, 9, 0);
    var fail = false;
    final source = ServerSource('http://m', client: MockClient((r) async {
      if (fail) return http.Response('busy', 503);
      final name = r.url.path == '/api/status' ? 'status' : r.url.path == '/api/compliance' ? 'compliance' : 'history_${r.url.pathSegments.last}';
      return http.Response(await File('assets/demo/$name.json').readAsString(), 200);
    }));
    final m = Monitor(source, clock: () => now);
    await m.refresh();
    expect(m.error, isNull);
    expect(m.stale, isFalse);
    fail = true;
    now = now.add(const Duration(seconds: 75));
    await m.refresh();
    expect(m.status, isNotNull);
    expect(m.error, contains('503'));
    expect(m.stale, isTrue);
  });

  test('live readings move the numbers between refreshes', () async {
    final m = Monitor(demo());
    await m.refresh();
    final t = m.status!.now + 30;
    m.apply(LiveReading('fridge-kitchen', t, 6.4, 55));
    expect(m.status!.units.first.state, 'warning');
    m.apply(LiveReading('coolroom', t, 3.1, 60));
    final cool = m.status!.units.last;
    expect(cool.state, 'ok');
    expect(cool.temp, 3.1);
    expect(m.secondsSince(cool.lastSeen), lessThan(5));
  });

  testWidgets('home shows the offline cool room first, then every unit', (tester) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final m = Monitor(demo());
    await tester.runAsync(m.refresh);
    await tester.pumpWidget(ColdRoomApp(monitor: m));
    await tester.pump();
    expect(find.textContaining('No readings for'), findsOneWidget);
    expect(find.text('Cool room'), findsNWidgets(2));
    expect(find.text('In range'), findsNWidgets(3));
    expect(find.textContaining('safe 0–5 °C'), findsNWidgets(3));
    await tester.tap(find.text('Display fridge'));
    await tester.pumpAndSettle();
    expect(find.text('Too warm'), findsOneWidget);
    expect(find.textContaining('worst'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Food safety record'));
    await tester.pumpAndSettle();
    expect(find.textContaining('% in range'), findsNWidgets(4));
    expect(find.textContaining('Too warm from'), findsOneWidget);
  });

  testWidgets('settings refuse an address that is not a web address', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final m = Monitor(demo());
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(monitor: m)));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'monitor.local');
    await tester.tap(find.text('Save and connect'));
    await tester.pump();
    expect(find.textContaining('Enter the full address'), findsOneWidget);
  });
}
