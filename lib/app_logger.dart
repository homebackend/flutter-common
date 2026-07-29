import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class TimestampPrinter extends LogPrinter {
  final _formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  final Map<Level, String> _emojis = {
    Level.trace: '🔍',
    Level.debug: '🐛',
    Level.info: '💡',
    Level.warning: '⚠️',
    Level.error: '⛔',
    Level.fatal: '💀',
  };

  final Map<Level, AnsiColor> _colors = {
    Level.trace: AnsiColor.fg(AnsiColor.grey(0.5)),
    Level.debug: AnsiColor.none(),
    Level.info: AnsiColor.fg(12),
    Level.warning: AnsiColor.fg(208),
    Level.error: AnsiColor.fg(196),
    Level.fatal: AnsiColor.fg(199),
  };

  @override
  List<String> log(LogEvent event) {
    final time = _formatter.format(DateTime.now());
    final emoji = _emojis[event.level] ?? '';
    final color = _colors[event.level] ?? AnsiColor.none();
    final level = event.level.name.toUpperCase();

    final msg = event.message;
    final errorStr = event.error != null ? "\nERROR: ${event.error}" : "";
    final stackStr = event.stackTrace != null ? "\n${event.stackTrace}" : "";

    return [color('$emoji $time [$level] $msg$errorStr$stackStr')];
  }
}

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  late final Logger _logger = Logger(
    printer: TimestampPrinter(),
    filter: kDebugMode ? DevelopmentFilter() : ProductionFilter(),
    level: Level.all,
  );

  void t(dynamic message) => _logger.t(message);
  void d(dynamic message) => _logger.d(message);
  void i(dynamic message) => _logger.i(message);
  void w(dynamic message) => _logger.w(message);
  void e(dynamic message, {dynamic error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
  void f(dynamic message, {dynamic error, StackTrace? stackTrace}) =>
      _logger.f(message, error: error, stackTrace: stackTrace);
}

final appLogger = AppLogger();
