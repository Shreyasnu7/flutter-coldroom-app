import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

/// Everything the screens show, kept fresh: a full refresh every 30 seconds plus live readings in between.
/// If the server can't be reached the last good data stays on screen, clearly marked with its age.
class Monitor extends ChangeNotifier {
  Source source;
  final Duration every;
  final DateTime Function() clock;
  Monitor(this.source, {this.every = const Duration(seconds: 30), DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  Status? status;
  Map<String, List<Point>> history = {};
  FoodSafetyRecord? record;
  String? error;
  DateTime? lastOk;
  bool loading = false;
  Timer? _timer;
  StreamSubscription<LiveReading>? _live;

  void start() {
    refresh();
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => refresh());
    _listen();
  }

  void use(Source s) {
    source = s;
    status = null;
    history = {};
    record = null;
    error = null;
    lastOk = null;
    notifyListeners();
    start();
  }

  void _listen() {
    _live?.cancel();
    try {
      _live = source.live()?.listen(apply, onError: (_) {}, cancelOnError: false);
    } catch (_) {
      _live = null;
    }
  }

  void apply(LiveReading r) {
    final s = status;
    if (s == null) return;
    status = Status(s.now > r.ts ? s.now : r.ts, [for (final u in s.units) u.id == r.device ? u.withReading(r.ts, r.temp, r.humidity) : u]);
    notifyListeners();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      final s = await source.status();
      final h = <String, List<Point>>{};
      for (final u in s.units) {
        h[u.id] = await source.history(u.id);
      }
      record = await source.record();
      status = s;
      history = h;
      error = null;
      lastOk = clock();
    } on ApiError catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Something went wrong reading the monitor: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// True when what's on screen is older than two refreshes.
  bool get stale => lastOk == null || clock().difference(lastOk!) > every * 2;

  /// Seconds since a unit last reported, by the server's clock plus the time since we asked.
  double secondsSince(double? ts) {
    final s = status;
    if (s == null || ts == null) return double.infinity;
    final sinceFetch = lastOk == null ? 0 : clock().difference(lastOk!).inSeconds;
    return s.now - ts + sinceFetch;
  }

  UnitRecord? recordFor(String id) => record?.units.where((u) => u.id == id).firstOrNull;

  @override
  void dispose() {
    _timer?.cancel();
    _live?.cancel();
    super.dispose();
  }
}
