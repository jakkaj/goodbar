import 'dart:io';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';

/// A scoped logger service that provides tagged logging with
/// file and console output.
/// 
/// Usage:
/// ```dart
/// final log = Log.scoped('MyComponent');
/// log.i('Initialization complete');
/// log.e('Error occurred', error, stackTrace);
/// ```
class Log {
  final Logger _logger;
  final String tag;

  Log._(this._logger, this.tag);

  /// Creates a scoped logger with the given [tag].
  /// 
  /// The [tag] is prepended to all log messages to identify the source.
  /// The [level] parameter sets the minimum log level (defaults to debug in dev, info in release).
  factory Log.scoped(String tag, {Level? level}) {
    final isRelease = kReleaseMode;
    final effectiveLevel = level ?? (isRelease ? Level.info : Level.debug);

    // Printer: Pretty in debug, Simple in release
    final basePrinter = isRelease
        ? SimplePrinter(printTime: true)
        : PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 8,
            lineLength: 140,
            colors: true,
            noBoxingByDefault: true,
            printTime: true,
          );
    
    // Use PrefixPrinter to cleanly add the tag
    final printer = PrefixPrinter(basePrinter, debug: '[$tag]');

    // Outputs: console always; file only if we can create it (and usually only in release)
    final outputs = <LogOutput>[ConsoleOutput()];
    final file = _resolveLogFile();
    if (file != null && isRelease) {
      outputs.add(FileOutput(file: file));
    }

    return Log._(
      Logger(
        level: effectiveLevel,
        filter: ProductionFilter(), // respects `level`
        printer: printer,
        output: MultiOutput(outputs),
      ),
      tag,
    );
  }

  /// Resolves the log file path, creating directories if needed.
  static File? _resolveLogFile() {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    
    try {
      final dir = Directory('$home/Library/Logs/goodbar')..createSync(recursive: true);
      return File('${dir.path}/app.log');
    } catch (e) {
      // Fallback to console only
      stderr.writeln('Log: could not create file: $e');
      return null;
    }
  }

  // Logger v2 APIs with **named** time, error and stackTrace parameters:
  /// Log a trace/verbose message.
  void t(String msg, [Object? e, StackTrace? st]) => 
    _logger.t(msg, time: DateTime.now(), error: e, stackTrace: st);
  
  /// Log a debug message.
  void d(String msg, [Object? e, StackTrace? st]) => 
    _logger.d(msg, time: DateTime.now(), error: e, stackTrace: st);
  
  /// Log an info message.
  void i(String msg, [Object? e, StackTrace? st]) => 
    _logger.i(msg, time: DateTime.now(), error: e, stackTrace: st);
  
  /// Log a warning message.
  void w(String msg, [Object? e, StackTrace? st]) => 
    _logger.w(msg, time: DateTime.now(), error: e, stackTrace: st);
  
  /// Log an error message.
  void e(String msg, [Object? e, StackTrace? st]) => 
    _logger.e(msg, time: DateTime.now(), error: e, stackTrace: st);
  
  /// Log a fatal message.
  void f(String msg, [Object? e, StackTrace? st]) => 
    _logger.f(msg, time: DateTime.now(), error: e, stackTrace: st);

  // Back-compat aliases
  /// Alias for trace - verbose logging.
  void v(String msg, [Object? e, StackTrace? st]) => t(msg, e, st);
  
  /// Alias for fatal - "What a Terrible Failure" logging.
  void wtf(String msg, [Object? e, StackTrace? st]) => f(msg, e, st);
}