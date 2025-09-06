import 'package:goodbar/src/core/models/display.dart';
import 'fixtures.dart';

/// Common display configuration scenarios for testing
/// 
/// These scenarios represent typical real-world display setups
/// that users might have, enabling comprehensive testing of
/// display detection and management features.
class TestScenarios {
  /// Laptop with no external displays
  /// 
  /// The simplest configuration - just the built-in display.
  /// Common for mobile work or presentations.
  static List<Display> laptopOnly() {
    return [DisplayBuilders.macBookPro16()];
  }
  
  /// Laptop docked with single external monitor
  /// 
  /// Common home office setup with one external display.
  /// Tests primary/secondary display handling.
  static List<Display> dockedSingleMonitor() {
    return [
      DisplayBuilders.macBookPro16(),
      DisplayBuilders.external4K(),
    ];
  }
  
  /// Full development setup with multiple monitors
  /// 
  /// Professional developer configuration with laptop
  /// plus two external monitors. Tests complex layouts.
  static List<Display> developerSetup() {
    return DisplayBuilders.threeDisplaySetup();
  }
  
  /// Presentation mode with projector
  /// 
  /// Laptop connected to a projector for presentations.
  /// Tests different resolution and scale factor handling.
  static List<Display> presentationMode() {
    return [
      DisplayBuilders.macBookPro16(),
      DisplayBuilders.custom(
        id: 'projector',
        width: 1920,
        height: 1080,
        x: 3456,
        y: 0,
        scaleFactor: 1.0,
        isPrimary: false,
      ),
    ];
  }
  
  /// Unusual configuration for edge case testing
  /// 
  /// Tests handling of vertical monitors, ultra-wide displays,
  /// and unusual positioning. Ensures robust display detection.
  static List<Display> edgeCase() {
    return [
      // Vertical monitor on left
      DisplayBuilders.custom(
        id: 'vertical',
        width: 1080,
        height: 1920,
        x: -1080,
        y: 0,
        scaleFactor: 1.0,
      ),
      // Primary in center
      DisplayBuilders.macBookPro16(),
      // Ultra-wide on right
      DisplayBuilders.custom(
        id: 'ultrawide',
        width: 5120,
        height: 1440,
        x: 3456,
        y: 0,
        scaleFactor: 1.5,
      ),
    ];
  }
}