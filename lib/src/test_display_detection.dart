import 'package:flutter/material.dart';
import 'package:goodbar/src/core/logging/app_logger.dart';
import 'package:goodbar/src/services/screen/macos_screen_service.dart';

class TestDisplayDetection extends StatefulWidget {
  const TestDisplayDetection({super.key});

  @override
  State<TestDisplayDetection> createState() => _TestDisplayDetectionState();
}

class _TestDisplayDetectionState extends State<TestDisplayDetection> {
  late final MacOSScreenService _screenService;
  String _displayInfo = 'Loading...';
  
  @override
  void initState() {
    super.initState();
    final logger = AppLogger(appName: 'goodbar');
    _screenService = MacOSScreenService(logger: logger);
    _loadDisplays();
  }
  
  @override
  void dispose() {
    _screenService.dispose();
    super.dispose();
  }
  
  Future<void> _loadDisplays() async {
    final result = await _screenService.getDisplays();
    
    result.when(
      success: (displays) {
        final buffer = StringBuffer();
        buffer.writeln('Detected ${displays.length} displays:\n');
        
        for (final display in displays) {
          buffer.writeln('Display ${display.id}:');
          buffer.writeln('  Primary: ${display.isPrimary}');
          buffer.writeln('  Position: (${display.bounds.x}, ${display.bounds.y})');
          buffer.writeln('  Size: ${display.bounds.width} x ${display.bounds.height}');
          buffer.writeln('  Work Area: ${display.workArea.width} x ${display.workArea.height}');
          buffer.writeln('  Scale: ${display.scaleFactor}x');
          buffer.writeln('  Menu Bar Height: ${display.menuBarHeight}px');
          buffer.writeln('  Dock Height: ${display.dockHeight}px');
          buffer.writeln();
        }
        
        setState(() {
          _displayInfo = buffer.toString();
        });
      },
      failure: (error) {
        setState(() {
          _displayInfo = 'Error: $error';
        });
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Display Detection Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your system has 3 displays attached.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _displayInfo,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _loadDisplays,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}