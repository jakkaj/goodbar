import 'dart:async';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/models/geometry.dart';
import 'package:goodbar/src/core/failures/screen_failures.dart';
import 'package:goodbar/src/services/screen/screen_service.dart';
import 'package:result_dart/result_dart.dart';

/// Fake implementation of ScreenService for testing.
/// 
/// Provides controllable display configurations for unit tests
/// and widget tests without requiring platform channel access.
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
    // Simulate async operation
    await Future.delayed(const Duration(milliseconds: 10));
    
    if (_failure != null) {
      return Failure(_failure!);
    }
    
    if (_displays.isEmpty) {
      return Failure(PlatformChannelFailure('No displays available'));
    }
    return Success(List.unmodifiable(_displays));
  }
  
  @override
  Future<Result<Display, ScreenFailure>> getDisplay(String displayId) async {
    await Future.delayed(const Duration(milliseconds: 10));
    
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
    await Future.delayed(const Duration(milliseconds: 10));
    
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