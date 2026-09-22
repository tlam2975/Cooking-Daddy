import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLogLevel { info, error }

class AppLogEntry {
  final DateTime timestamp;
  final AppLogLevel level;
  final String message;
  final String? stackTrace;

  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.stackTrace,
  });

  factory AppLogEntry.fromJson(Map<String, dynamic> json) {
    return AppLogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: AppLogLevel.values.byName(json['level'] as String),
      message: json['message'] as String,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    'stackTrace': stackTrace,
  };

  String get formatted {
    final label = level.name.toUpperCase();
    final stack = stackTrace == null ? '' : '\n$stackTrace';
    return '[${timestamp.toIso8601String()}] [$label] $message$stack';
  }
}

class AppLogService extends ChangeNotifier {
  AppLogService._();

  static final AppLogService instance = AppLogService._();

  static const _storageKey = 'app_logs_v1';
  static const _maxEntries = 300;
  static const _maxFieldLength = 8000;

  final List<AppLogEntry> _entries = [];
  SharedPreferences? _preferences;
  Timer? _persistTimer;

  List<AppLogEntry> get entries => List.unmodifiable(_entries.reversed);

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    final stored = _preferences?.getStringList(_storageKey) ?? const [];
    final restored = <AppLogEntry>[];

    for (final raw in stored) {
      try {
        restored.add(AppLogEntry.fromJson(jsonDecode(raw)));
      } catch (_) {
        // Ignore malformed legacy entries instead of breaking app startup.
      }
    }

    _entries
      ..clear()
      ..addAll(restored.take(_maxEntries));
    notifyListeners();
  }

  void info(String message) => _add(AppLogLevel.info, message);

  void error(String message, [StackTrace? stackTrace]) {
    _add(AppLogLevel.error, message, stackTrace);
  }

  Future<void> clear() async {
    _persistTimer?.cancel();
    _entries.clear();
    notifyListeners();
    await _preferences?.remove(_storageKey);
  }

  void _add(AppLogLevel level, String message, [StackTrace? stackTrace]) {
    _entries.add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: _truncate(message),
        stackTrace: stackTrace == null ? null : _truncate('$stackTrace'),
      ),
    );

    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }

    notifyListeners();
    _schedulePersist();
  }

  void _schedulePersist() {
    if (_preferences == null) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 300), () async {
      final encoded = _entries
          .map((entry) => jsonEncode(entry.toJson()))
          .toList();
      try {
        await _preferences?.setStringList(_storageKey, encoded);
      } catch (_) {
        // Logging must never cause an app failure.
      }
    });
  }

  String _truncate(String value) {
    if (value.length <= _maxFieldLength) return value;
    return '${value.substring(0, _maxFieldLength)}\n[truncated]';
  }
}
