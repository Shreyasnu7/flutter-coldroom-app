import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../monitor.dart';

const prefServer = 'server_url';

Future<Source> savedSource() async {
  final prefs = await SharedPreferences.getInstance();
  final url = prefs.getString(prefServer) ?? '';
  return url.isEmpty ? DemoSource() : ServerSource(url);
}

class SettingsScreen extends StatefulWidget {
  final Monitor monitor;
  const SettingsScreen({super.key, required this.monitor});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final url = TextEditingController();
  String? message;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => url.text = p.getString(prefServer) ?? ''));
  }

  String? validate(String v) {
    if (v.isEmpty) return null;
    final u = Uri.tryParse(v);
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) return 'Enter the full address, e.g. https://monitor.example.com';
    return null;
  }

  Future<void> save() async {
    final v = url.text.trim();
    final problem = validate(v);
    if (problem != null) {
      setState(() => message = problem);
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    final source = v.isEmpty ? DemoSource() : ServerSource(v);
    try {
      final s = await source.status();
      (await SharedPreferences.getInstance()).setString(prefServer, v);
      widget.monitor.use(source);
      setState(() => message = v.isEmpty ? 'Using the demo day.' : 'Connected: ${s.units.length} units.');
    } on ApiError catch (e) {
      setState(() => message = e.message);
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Monitor address', hintText: 'https://monitor.example.com', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 6),
        Text('Leave empty to look around with a recorded demo day.', style: TextStyle(color: muted, fontSize: 12.5)),
        const SizedBox(height: 14),
        Row(children: [
          FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Checking...' : 'Save and connect')),
          const SizedBox(width: 12),
          if (message != null) Expanded(child: Text(message!)),
        ]),
      ]),
    );
  }
}
