import 'package:flutter/material.dart';

import 'monitor.dart';
import 'screens/settings_screen.dart';
import 'screens/units_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final monitor = Monitor(await savedSource())..start();
  runApp(ColdRoomApp(monitor: monitor));
}

class ColdRoomApp extends StatelessWidget {
  final Monitor monitor;
  const ColdRoomApp({super.key, required this.monitor});

  static ThemeData theme(Brightness b) => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6670), brightness: b),
        useMaterial3: true,
        cardTheme: const CardTheme(elevation: 0.5),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Cold storage',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        home: UnitsScreen(monitor: monitor),
      );
}
