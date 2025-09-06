import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/models/geometry.dart';

/// Test data builders for Display models
/// 
/// These builders provide sensible defaults while allowing specific overrides.
/// They represent realistic display configurations from actual macOS systems.
class DisplayBuilders {
  /// Creates a MacBook Pro 16" built-in Retina display (primary)
  static Display macBookPro16({
    String id = '1',
    bool isPrimary = true,
  }) {
    return Display(
      id: id,
      bounds: const Rectangle(x: 0, y: 0, width: 3456, height: 2234),
      workArea: const Rectangle(x: 0, y: 25, width: 3456, height: 2184),
      scaleFactor: 2.0,
      isPrimary: isPrimary,
    );
  }

  /// Creates a 4K external monitor
  static Display external4K({
    String id = '2',
    double x = 3456,
    double y = 0,
  }) {
    return Display(
      id: id,
      bounds: Rectangle(x: x, y: y, width: 3840, height: 2160),
      workArea: Rectangle(x: x, y: y, width: 3840, height: 2160),
      scaleFactor: 2.0,
      isPrimary: false,
    );
  }

  /// Creates a 1080p external monitor
  static Display external1080p({
    String id = '3',
    double x = 0,
    double y = -1080,
  }) {
    return Display(
      id: id,
      bounds: Rectangle(x: x, y: y, width: 1920, height: 1080),
      workArea: Rectangle(x: x, y: y, width: 1920, height: 1080),
      scaleFactor: 1.0,
      isPrimary: false,
    );
  }

  /// Creates a standard 3-display development setup
  static List<Display> threeDisplaySetup() {
    return [
      macBookPro16(),
      external4K(),
      external1080p(),
    ];
  }

  /// Creates a custom display with specific properties
  static Display custom({
    required String id,
    required double width,
    required double height,
    double x = 0,
    double y = 0,
    double scaleFactor = 1.0,
    bool isPrimary = false,
    double menuBarHeight = 25,
  }) {
    return Display(
      id: id,
      bounds: Rectangle(x: x, y: y, width: width, height: height),
      workArea: Rectangle(
        x: x, 
        y: y + (isPrimary ? menuBarHeight : 0), 
        width: width, 
        height: height - (isPrimary ? menuBarHeight : 0),
      ),
      scaleFactor: scaleFactor,
      isPrimary: isPrimary,
    );
  }
}