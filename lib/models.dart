// Shapes returned by the cold-storage monitor's API (iot-dashboard/backend/main.py).

double? _num(Object? v) => v == null ? null : (v as num).toDouble();

class Unit {
  final String id;
  final String name;
  final double min;
  final double max;
  final double? temp;
  final double? humidity;
  final double? battery;
  final double? lastSeen; // epoch seconds, server clock
  final String state; // ok, warning, alert, offline, no data
  final double? alertSince;

  const Unit({
    required this.id,
    required this.name,
    required this.min,
    required this.max,
    this.temp,
    this.humidity,
    this.battery,
    this.lastSeen,
    required this.state,
    this.alertSince,
  });

  factory Unit.fromJson(Map<String, dynamic> j) => Unit(
        id: j['id'] as String,
        name: j['name'] as String,
        min: _num(j['min'])!,
        max: _num(j['max'])!,
        temp: _num(j['temp']),
        humidity: _num(j['humidity']),
        battery: _num(j['battery']),
        lastSeen: _num(j['last_seen']),
        state: j['state'] as String,
        alertSince: _num(j['alert_since']),
      );

  bool get isFreezer => max < 0;
  bool inRange(double t) => t >= min && t <= max;
  String get limitText => isFreezer ? '${max.toStringAsFixed(0)} °C or colder' : '${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)} °C';

  /// A live reading moves the temperature; an out-of-range reading on a healthy unit shows as a warning
  /// until the server decides it has lasted long enough to be an alert.
  Unit withReading(double ts, double t, double? hum) => Unit(
        id: id,
        name: name,
        min: min,
        max: max,
        temp: t,
        humidity: hum ?? humidity,
        battery: battery,
        lastSeen: ts,
        state: state == 'offline' || state == 'no data'
            ? (inRange(t) ? 'ok' : 'warning')
            : state == 'alert'
                ? 'alert'
                : (inRange(t) ? 'ok' : 'warning'),
        alertSince: state == 'offline' ? null : alertSince,
      );
}

class Status {
  final double now; // server time, so "how long ago" doesn't depend on the phone's clock
  final List<Unit> units;
  const Status(this.now, this.units);

  factory Status.fromJson(Map<String, dynamic> j) =>
      Status(_num(j['now'])!, (j['devices'] as List).map((d) => Unit.fromJson(d as Map<String, dynamic>)).toList());

  List<Unit> get needingAttention => units.where((u) => u.state == 'alert' || u.state == 'offline').toList();
}

class Point {
  final double t;
  final double temp;
  final double hi;
  const Point(this.t, this.temp, this.hi);
  factory Point.fromJson(Map<String, dynamic> j) => Point(_num(j['t'])!, _num(j['temp'])!, _num(j['hi'])!);
}

class Excursion {
  final String kind; // temperature or offline
  final double started;
  final double? ended;
  final double? peak;
  const Excursion(this.kind, this.started, this.ended, this.peak);
  factory Excursion.fromJson(Map<String, dynamic> j) =>
      Excursion(j['kind'] as String, _num(j['started'])!, _num(j['ended']), _num(j['peak']));

  Duration? get length => ended == null ? null : Duration(seconds: (ended! - started).round());

  /// The server records "temperature" alerts; which way it went follows from the worst value and the unit's limits.
  String title(Unit? unit) {
    if (kind == 'offline') return 'No readings';
    if (peak != null && unit != null && peak! < unit.min) return 'Too cold';
    return 'Too warm';
  }
}

class UnitRecord {
  final String id;
  final String name;
  final String limit;
  final int readings;
  final double? inRangePct;
  final double? min;
  final double? max;
  final List<Excursion> excursions;
  const UnitRecord(this.id, this.name, this.limit, this.readings, this.inRangePct, this.min, this.max, this.excursions);

  factory UnitRecord.fromJson(Map<String, dynamic> j) => UnitRecord(
        j['id'] as String,
        j['name'] as String,
        j['limit'] as String,
        (j['readings'] as num).toInt(),
        _num(j['in_range_pct']),
        _num(j['min']),
        _num(j['max']),
        (j['alerts'] as List).map((a) => Excursion.fromJson(a as Map<String, dynamic>)).toList(),
      );
}

class FoodSafetyRecord {
  final double from;
  final double to;
  final List<UnitRecord> units;
  const FoodSafetyRecord(this.from, this.to, this.units);
  factory FoodSafetyRecord.fromJson(Map<String, dynamic> j) => FoodSafetyRecord(
      _num(j['from'])!, _num(j['to'])!, (j['devices'] as List).map((d) => UnitRecord.fromJson(d as Map<String, dynamic>)).toList());
}

class LiveReading {
  final String device;
  final double ts;
  final double temp;
  final double? humidity;
  const LiveReading(this.device, this.ts, this.temp, this.humidity);
}
