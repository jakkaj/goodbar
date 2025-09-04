import 'dart:io';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';

/// A logger service for the application that provides tagged logging
/// with file and console output.
/// 
/// This follows the service layer pattern from docs/rules/service-layer.md
/// where services receive logger instances via dependency injection.
/// 
/// Usage:
/// ```dart
/// // Create root logger
/// final logger = AppLogger(appName: 'goodbar');
/// 
/// // Create tagged logger for a service
/// final serviceLogger = logger.tag('ScreenService');
/// serviceLogger.i('Fetching displays');
/// ```
class AppLogger {
  final Logger _inner;
  final Level _level;
  final LogFilter _filter;
  final LogPrinter _printer;
  final LogOutput _output;
  
  AppLogger._(this._inner, this._level, this._filter, this._printer, this._output);
  
  /// Creates a root logger with the given [appName] and optional [fileName].
  /// 
  /// The [appName] is used for the log directory path.
  /// The [fileName] is used for file output (only in release mode).
  /// The [level] parameter sets the minimum log level (defaults to debug in dev, info in release).
  factory AppLogger({
    String appName = 'goodbar', 
    String? fileName,
    Level? level,
  }) {
    final isRelease = kReleaseMode;
    final effectiveLevel = level ?? (isRelease ? Level.info : Level.debug);
    
    // Outputs: console always; file only if fileName provided and in release
    final outputs = <LogOutput>[ConsoleOutput()];
    if (isRelease && fileName != null && Platform.isMacOS) {
      final file = _resolveLogFile(appName, fileName);
      if (file != null) {
        outputs.add(FileOutput(file: file));
      }
    }
    
    // Printer: Pretty in debug, Simple in release
    final printer = isRelease
        ? SimplePrinter(printTime: true)
        : PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 8,
            lineLength: 140,
            colors: true,
            noBoxingByDefault: true,
            printTime: true,
          );
    
    final filter = ProductionFilter(); // respects `level`
    final output = MultiOutput(outputs);
    
    return AppLogger._(
      Logger(
        level: effectiveLevel,
        filter: filter,
        printer: printer,
        output: output,
      ),
      effectiveLevel,
      filter,
      printer,
      output,
    );
  }
  
  /// Creates a tagged instance of this logger.
  /// 
  /// The [tag] is prepended to all log messages from the returned logger
  /// to identify the source component/service.
  AppLogger tag(String tag) {
    final taggedPrinter = PrefixPrinter(_printer, debug: '[$tag]');
    return AppLogger._(
      Logger(
        level: _level,
        filter: _filter,
        printer: taggedPrinter,
        output: _output,
      ),
      _level,
      _filter,
      taggedPrinter,
      _output,
    );
  }
  
  /// Resolves the log file path, creating directories if needed.
  static File? _resolveLogFile(String appName, String fileName) {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    
    try {
      final dir = Directory('$home/Library/Logs/$appName')
        ..createSync(recursive: true);
      return File('${dir.path}/$fileName');
    } catch (e) {
      // Fallback to console only
      stderr.writeln('AppLogger: could not create file: $e');
      return null;
    }
  }
  
  // Ergonomic shorthands with positional parameters as per service-layer.md
  
  /// Log a debug message.
  void d(String m, [Object? e, StackTrace? s]) => 
    _inner.d(m, time: DateTime.now(), error: e, stackTrace: s);
  
  /// Log an info message.
  void i(String m, [Object? e, StackTrace? s]) => 
    _inner.i(m, time: DateTime.now(), error: e, stackTrace: s);
  
  /// Log a warning message.
  void w(String m, [Object? e, StackTrace? s]) => 
    _inner.w(m, time: DateTime.now(), error: e, stackTrace: s);
  
  /// Log an error message.
  void e(String m, [Object? e, StackTrace? s]) => 
    _inner.e(m, time: DateTime.now(), error: e, stackTrace: s);
  
  /// Log a fatal message.
  void f(String m, [Object? e, StackTrace? s]) => 
    _inner.f(m, time: DateTime.now(), error: e, stackTrace: s);
}