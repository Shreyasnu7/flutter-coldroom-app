import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';

class ApiError implements Exception {
  final String message;
  const ApiError(this.message);
  @override
  String toString() => message;
}

/// Where the data comes from: the monitor's server, or the bundled demo day.
abstract class Source {
  Future<Status> status();
  Future<List<Point>> history(String unitId, {int hours = 24});
  Future<FoodSafetyRecord> record({int hours = 24});

  /// Readings as they arrive, if the source can push them.
  Stream<LiveReading>? live();
  String get label;
}

class ServerSource implements Source {
  final Uri base;
  final http.Client client;
  final Duration timeout;
  ServerSource(String url, {http.Client? client, this.timeout = const Duration(seconds: 10)})
      : base = Uri.parse(url.endsWith('/') ? url.substring(0, url.length - 1) : url),
        client = client ?? http.Client();

  @override
  String get label => base.host;

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final uri = base.replace(path: '${base.path}$path', queryParameters: query);
    final http.Response r;
    try {
      r = await client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const ApiError("The monitor didn't answer in time.");
    } catch (_) {
      throw ApiError("Can't reach the monitor at ${base.host}.");
    }
    if (r.statusCode != 200) throw ApiError('The monitor answered ${r.statusCode}.');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  @override
  Future<Status> status() async => Status.fromJson(await _get('/api/status') as Map<String, dynamic>);

  @override
  Future<List<Point>> history(String unitId, {int hours = 24}) async =>
      ((await _get('/api/history/$unitId', {'hours': '$hours'})) as List).map((p) => Point.fromJson(p as Map<String, dynamic>)).toList();

  @override
  Future<FoodSafetyRecord> record({int hours = 24}) async =>
      FoodSafetyRecord.fromJson(await _get('/api/compliance', {'hours': '$hours'}) as Map<String, dynamic>);

  @override
  Stream<LiveReading>? live() {
    final ws = base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '${base.path}/ws');
    final channel = WebSocketChannel.connect(ws);
    return channel.stream.map((m) => jsonDecode(m as String) as Map<String, dynamic>).where((m) => m['type'] == 'reading').map((m) =>
        LiveReading(m['device'] as String, (m['ts'] as num).toDouble(), (m['temp'] as num).toDouble(), (m['humidity'] as num?)?.toDouble()));
  }
}

/// A real day captured from the monitor (simulate.py: service-time door openings, the display fridge left ajar,
/// the cool-room sensor going flat), so the app can be tried without a server.
class DemoSource implements Source {
  final Future<String> Function(String) load;
  DemoSource({Future<String> Function(String)? load}) : load = load ?? rootBundle.loadString;

  @override
  String get label => 'demo data';

  Future<dynamic> _asset(String name) async => jsonDecode(await load('assets/demo/$name.json'));

  @override
  Future<Status> status() async => Status.fromJson(await _asset('status') as Map<String, dynamic>);

  @override
  Future<List<Point>> history(String unitId, {int hours = 24}) async =>
      ((await _asset('history_$unitId')) as List).map((p) => Point.fromJson(p as Map<String, dynamic>)).toList();

  @override
  Future<FoodSafetyRecord> record({int hours = 24}) async => FoodSafetyRecord.fromJson(await _asset('compliance') as Map<String, dynamic>);

  @override
  Stream<LiveReading>? live() => null;
}
