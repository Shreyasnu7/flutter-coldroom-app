# Cold storage: Flutter phone app

The phone app for the cold-room temperature monitor (the `iot-dashboard` server and the `pcb-design` sensor board). The kitchen manager can see at a glance whether every fridge, freezer and cool room is safe, and look into anything that isn't.

- **Home:** every unit's temperature, its safe range, when it last reported, and a 24-hour sparkline with out-of-range stretches in red. Units in alarm or not reporting are pinned to the top, with what to do about them.
- **Unit:** a 24-hour chart with the safe band shaded and gaps where readings stopped; time in range, lowest and highest; and every excursion, with its start, length and worst temperature.
- **Food safety record:** the 24-hour record an inspector asks for, against the FSANZ 3.2.2 limits.
- **Live:** a full refresh every 30 seconds, and readings over the server's WebSocket in between.

**Handling problems**
- If the server can't be reached, the last data stays on screen with its age and a clear warning; it never goes blank.
- "Last reported" times use the server's clock, so a phone with the wrong time doesn't make a fridge look offline.
- With no server set, the app runs on a real day recorded from the monitor (`assets/demo/`): door openings at service times, the display fridge left ajar for 43 minutes, and the cool-room sensor going flat.

## Run it

```
flutter pub get
flutter run                      # Android, iOS or web; Settings > Monitor address, e.g. https://monitor.example.com
flutter build apk --release
```

The app talks to the monitor's API: `/api/status`, `/api/history/{unit}`, `/api/compliance` and `/ws`.

## Tests

`flutter test` runs 6 tests:
- parsing of the recorded day;
- server errors turned into plain messages;
- keeping stale data when the server drops out;
- live readings updating units;
- the home, unit and record screens;
- settings refusing an invalid address.

`test/live_server_test.dart` also runs against a real monitor when `MONITOR_URL` is set. Start `python backend/main.py` and `python simulate.py` in `iot-dashboard` first.
