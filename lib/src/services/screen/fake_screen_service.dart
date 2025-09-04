import 'dart:async';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/models/geometry.dart';
import 'package:goodbar/src/core/models/result.dart';
import 'package:goodbar/src/services/screen/screen_service.dart';

/// Fake implementation of ScreenService for testing.
/// 
/// Provides controllable display configurations for unit tests
/// and widget tests without requiring platform channel access.
class FakeScreenService implements ScreenService {
  List<Display> _displays;
  final _displayChangeController = StreamController<DisplayChangeEvent>.broadcast();
  
  /// Creates a fake screen service with the given displays.
  /// 
  /// If no displays are provided, creates a default 3-display setup
  /// mimicking a typical development environment.
  FakeScreenService({List<Display>? displays}) 
      : _displays = displays ?? _createDefaultDisplays();
  
  /// Creates a default 3-display configuration for testing.
  static List<Display> _createDefaultDisplays() {
    return [
      // Primary display - MacBook Pro 16" built-in Retina display
      const Display(
        id: '1',
        bounds: Rectangle(x: 0, y: 0, width: 3456, height: 2234),
        workArea: Rectangle(x: 0, y: 25, width: 3456, height: 2184),
        scaleFactor: 2.0,
        isPrimary: true,
      ),
      // Secondary display - External 4K monitor to the right
      const Display(
        id: '2',
        bounds: Rectangle(x: 3456, y: 0, width: 3840, height: 2160),
        workArea: Rectangle(x: 3456, y: 0, width: 3840, height: 2160),
        scaleFactor: 2.0,
        isPrimary: false,
      ),
      // Tertiary display - External 1080p monitor above
      const Display(
        id: '3',
        bounds: Rectangle(x: 0, y: -1080, width: 1920, height: 1080),
        workArea: Rectangle(x: 0, y: -1080, width: 1920, height: 1080),
        scaleFactor: 1.0,
        isPrimary: false,
      ),
    ];
  }
  
  /// Updates the fake displays and emits a change event.
  void setDisplays(List<Display> displays) {
    _displays = displays;
    _displayChangeController.add(DisplayChangeEvent(
      displays: displays,
      changeType: 'reconfigured',
      timestamp: DateTime.now(),
    ));
  }
  
  /// Simulates adding a new display.
  void addDisplay(Display display) {
    _displays.add(display);
    _displayChangeController.add(DisplayChangeEvent(
      displays: _displays,
      changeType: 'added',
      timestamp: DateTime.now(),
    ));
  }
  
  /// Simulates removing a display by ID.
  void removeDisplay(String displayId) {
    _displays.removeWhere((d) => d.id == displayId);
    _displayChangeController.add(DisplayChangeEvent(
      displays: _displays,
      changeType: 'removed',
      timestamp: DateTime.now(),
    ));
  }
  
  @override
  Future<Result<List<Display>, String>> getDisplays() async {
    // Simulate async operation
    await Future.delayed(const Duration(milliseconds: 10));
    
    if (_displays.isEmpty) {
      return const Result.failure('No displays available');
    }
    return Result.success(List.unmodifiable(_displays));
  }
  
  @override
  Future<Result<Display, String>> getDisplay(String displayId) async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    try {
      final display = _displays.firstWhere((d) => d.id == displayId);
      return Result.success(display);
    } catch (_) {
      return Result.failure('Display $displayId not found');
    }
  }
  
  @override
  Future<Result<Display, String>> getPrimaryDisplay() async {
    await Future.delayed(const Duration(milliseconds: 10));
    
    try {
      final primary = _displays.firstWhere((d) => d.isPrimary);
      return Result.success(primary);
    } catch (_) {
      return const Result.failure('No primary display found');
    }
  }
  
  @override
  Stream<DisplayChangeEvent> get displayChanges => _displayChangeController.stream;
  
  @override
  void dispose() {
    _displayChangeController.close();
  }
}