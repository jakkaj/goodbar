import 'package:flutter_test/flutter_test.dart';
import 'package:goodbar/src/core/models/display.dart';

/// Test assertions for Display properties
/// 
/// Provides comprehensive validation methods for Display objects,
/// ensuring all properties meet expected constraints and relationships.
class DisplayAssertions {
  /// Asserts that display properties are valid
  /// 
  /// Performs comprehensive validation including:
  /// - Positive dimensions
  /// - Valid scale factor
  /// - Work area within bounds
  /// - Consistent menu bar calculation
  static void assertValidDisplay(Display display) {
    // Basic property validation
    expect(display.id, isNotEmpty,
        reason: 'Display must have non-empty ID');
    expect(display.scaleFactor, greaterThan(0),
        reason: 'Scale factor must be positive');
    
    // Dimension validation
    expect(display.width, greaterThan(0),
        reason: 'Display width must be positive');
    expect(display.height, greaterThan(0),
        reason: 'Display height must be positive');
    
    // Work area validation
    expect(display.workArea.width, lessThanOrEqualTo(display.bounds.width),
        reason: 'Work area width cannot exceed bounds width');
    expect(display.workArea.height, lessThanOrEqualTo(display.bounds.height),
        reason: 'Work area height cannot exceed bounds height');
    
    // Menu bar validation for primary display
    if (display.isPrimary) {
      expect(display.menuBarHeight, greaterThanOrEqualTo(0),
          reason: 'Menu bar height must be non-negative');
      
      // Menu bar should reduce work area
      if (display.menuBarHeight > 0) {
        expect(
          display.workArea.height,
          lessThan(display.bounds.height),
          reason: 'Primary display work area should be reduced by menu bar',
        );
      }
    }
  }
  
  /// Asserts that exactly one display is primary
  /// 
  /// Validates that a list of displays has exactly one
  /// display marked as primary, as required by the system.
  static void assertSinglePrimary(List<Display> displays) {
    final primaryCount = displays.where((d) => d.isPrimary).length;
    expect(
      primaryCount,
      equals(1),
      reason: 'Exactly one display must be marked as primary',
    );
  }
  
  /// Asserts display positioning is valid
  /// 
  /// Checks that displays don't overlap and have
  /// reasonable positioning relative to each other.
  static void assertValidPositioning(List<Display> displays) {
    for (int i = 0; i < displays.length; i++) {
      for (int j = i + 1; j < displays.length; j++) {
        final d1 = displays[i];
        final d2 = displays[j];
        
        // Check for overlap (simplified - just checks if corners overlap)
        final overlap = d1.bounds.right > d2.bounds.left &&
            d1.bounds.left < d2.bounds.right &&
            d1.bounds.bottom > d2.bounds.top &&
            d1.bounds.top < d2.bounds.bottom;
            
        expect(
          overlap,
          isFalse,
          reason: 'Display ${d1.id} and ${d2.id} should not overlap',
        );
      }
    }
  }
  
  /// Asserts display has expected properties
  /// 
  /// Convenience method for checking multiple properties at once.
  static void assertDisplayProperties(
    Display display, {
    String? id,
    bool? isPrimary,
    double? scaleFactor,
    double? width,
    double? height,
  }) {
    if (id != null) {
      expect(display.id, equals(id));
    }
    if (isPrimary != null) {
      expect(display.isPrimary, equals(isPrimary));
    }
    if (scaleFactor != null) {
      expect(display.scaleFactor, equals(scaleFactor));
    }
    if (width != null) {
      expect(display.width, equals(width));
    }
    if (height != null) {
      expect(display.height, equals(height));
    }
  }
}