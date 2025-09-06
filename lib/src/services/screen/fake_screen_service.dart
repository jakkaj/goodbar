import 'dart:async';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/models/geometry.dart';
import 'package:goodbar/src/core/failures/screen_failures.dart';
import 'package:goodbar/src/services/screen/screen_service.dart';
import 'package:result_dart/result_dart.dart';

/// Fake implementation of ScreenService for testing and development.
/// 
/// This service lives in the production codebase rather than test/
/// for several important reasons:
/// 
/// 1. **Development Mode**: Can be used during development to simulate
///    different display configurations without physical monitors.
/// 
/// 2. **Demo/Example Apps**: Useful for creating reproducible demos
///    or examples that don't require actual hardware.
/// 
/// 3. **Provider Integration**: Has a dedicated provider in services.dart
///    (`fakeScreenServiceProvider`) allowing easy switching between
///    real and fake implementations.
/// 
/// 4. **Widget Preview**: Can be used in tools like Widgetbook or
///    Flutter's widget preview to show different display scenarios.
/// 
/// For testing, this service provides:
/// - Controllable display configurations
/// - Failure simulation
/// - Stream-based display change events
/// - Deterministic behavior (no async delays)
class FakeScreenService implements ScreenService {
  List<Display> _displays;
  ScreenFailure? _failure;
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
  
  /// Sets a failure to be returned by subsequent operations.
  void setFailure(ScreenFailure failure) {
    _failure = failure;
  }
  
  /// Clears any set failure.
  void clearFailure() {
    _failure = null;
  }
  
  /// Emits a display change event without changing displays.
  void emitDisplayChange(List<Display> displays) {
    _displays = displays;
    _displayChangeController.add(DisplayChangeEvent(
      displays: displays,
      changeType: 'changed',
      timestamp: DateTime.now(),
    ));
  }
  
  @override
  Future<Result<List<Display>, ScreenFailure>> getDisplays() async {
    // Simulate async operation without introducing pending timers in tests
    // (returning immediately keeps widget tests deterministic)
    
    if (_failure != null) {
      return Failure(_failure!);
    }
    
    if (_displays.isEmpty) {
      // For testing UI empty states, return success with empty list
      return Success(const <Display>[]);
    }
    return Success(List.unmodifiable(_displays));
  }
  
  @override
  Future<Result<Display, ScreenFailure>> getDisplay(String displayId) async {
    // Return immediately for deterministic tests
    
    if (_failure != null) {
      return Failure(_failure!);
    }
    
    try {
      final display = _displays.firstWhere((d) => d.id == displayId);
      return Success(display);
    } catch (_) {
      return Failure(DisplayNotFoundFailure(displayId));
    }
  }
  
  @override
  Future<Result<Display, ScreenFailure>> getPrimaryDisplay() async {
    // Return immediately for deterministic tests
    
    if (_failure != null) {
      return Failure(_failure!);
    }
    
    try {
      final primary = _displays.firstWhere((d) => d.isPrimary);
      return Success(primary);
    } catch (_) {
      return Failure(PlatformChannelFailure('No primary display found'));
    }
  }
  
  @override
  Stream<DisplayChangeEvent> get displayChanges => _displayChangeController.stream;
  
  @override
  void dispose() {
    _displayChangeController.close();
  }
}
