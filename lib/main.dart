import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/bootstrap/logger_providers.dart';
import 'src/core/logging/app_logger.dart';
import 'src/widgets/displays_screen.dart';

void main() {
  // Create root logger with file output
  final rootLog = AppLogger(appName: 'goodbar', fileName: 'app.log');
  
  // Basic error handler using logger
  FlutterError.onError = (details) {
    rootLog.e('FlutterError', details.exception, details.stack);
  };
  
  // Wrap app in ProviderScope for dependency injection
  runApp(
    ProviderScope(
      overrides: [
        // Inject the logger for all providers to use
        loggerRootProvider.overrideWithValue(rootLog),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goodbar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const DisplaysScreen(), // Using our new Riverpod screen
    );
  }
}
