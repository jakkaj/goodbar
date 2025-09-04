import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/models/result.dart';

/// Service interface for accessing display/screen information.
/// 
/// This provides platform-agnostic access to display configuration,
/// enabling the UI layer to query and react to multi-display setups
/// without knowing about platform-specific implementation details.
abstract class ScreenService {
  /// Gets all currently connected displays.
  /// 
  /// Returns a Result containing either:
  /// - Success: List of all connected displays with their properties
  /// - Failure: Error message if display information cannot be retrieved
  Future<Result<List<Display>, String>> getDisplays();
  
  /// Gets a specific display by its ID.
  /// 
  /// Returns a Result containing either:
  /// - Success: The requested display if found
  /// - Failure: Error message if display not found or cannot be retrieved
  Future<Result<Display, String>> getDisplay(String displayId);
  
  /// Gets the primary display.
  /// 
  /// Returns a Result containing either:
  /// - Success: The primary display
  /// - Failure: Error message if no primary display found
  Future<Result<Display, String>> getPrimaryDisplay();
  
  /// Stream of display configuration changes.
  /// 
  /// Emits events when displays are:
  /// - Connected or disconnected
  /// - Rearranged or reconfigured
  /// - Resolution or scale factor changed
  Stream<DisplayChangeEvent> get displayChanges;
  
  /// Disposes of any resources used by the service.
  /// 
  /// Should be called when the service is no longer needed
  /// to clean up event listeners and platform channels.
  void dispose();
}