import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String temp(double? t) => t == null ? '–' : '${t.toStringAsFixed(1)} °C';

String ago(double seconds) {
  if (seconds.isInfinite) return 'never';
  if (seconds < 90) return 'just now';
  final m = (seconds / 60).round();
  if (m < 60) return '$m min ago';
  final h = m ~/ 60;
  return h < 48 ? '$h h ${m % 60} min ago' : '${h ~/ 24} days ago';
}

String span(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  return '${d.inHours} h ${d.inMinutes % 60} min';
}

DateTime at(double epoch) => DateTime.fromMillisecondsSinceEpoch((epoch * 1000).round());
String clock(double epoch) => DateFormat('h:mm a').format(at(epoch)).toLowerCase();
String dayClock(double epoch) => DateFormat('EEE d MMM, h:mm a').format(at(epoch)).replaceAll('AM', 'am').replaceAll('PM', 'pm');

class StateStyle {
  final String label;
  final Color fg;
  final Color bg;
  final IconData icon;
  const StateStyle(this.label, this.fg, this.bg, this.icon);
}

StateStyle styleFor(String state, Brightness b) {
  final dark = b == Brightness.dark;
  switch (state) {
    case 'ok':
      return StateStyle('In range', dark ? const Color(0xFF8FD3A4) : const Color(0xFF256B3C), dark ? const Color(0xFF1C3626) : const Color(0xFFE1F1E5), Icons.check_circle_outline);
    case 'warning':
      return StateStyle('Out of range', dark ? const Color(0xFFF2C46B) : const Color(0xFF8A5A00), dark ? const Color(0xFF3A2E14) : const Color(0xFFF8ECD2), Icons.schedule);
    case 'alert':
      return StateStyle('Alarm', dark ? const Color(0xFFF59A86) : const Color(0xFFA83220), dark ? const Color(0xFF3E1E18) : const Color(0xFFF9E0DA), Icons.warning_amber_rounded);
    case 'offline':
      return StateStyle('No readings', dark ? const Color(0xFFC9C4BA) : const Color(0xFF5F5A51), dark ? const Color(0xFF302E2A) : const Color(0xFFECE9E3), Icons.sensors_off_outlined);
    default:
      return StateStyle('Waiting', dark ? const Color(0xFFC9C4BA) : const Color(0xFF5F5A51), dark ? const Color(0xFF302E2A) : const Color(0xFFECE9E3), Icons.hourglass_empty);
  }
}
