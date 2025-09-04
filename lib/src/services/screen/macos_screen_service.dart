import 'dart:async';
import 'package:flutter/services.dart';
import 'package:goodbar/src/core/logging/app_logger.dart';
import 'package:goodbar/src/core/models/display.dart';
import 'package:goodbar/src/core/models/geometry.dart';
import 'package:goodbar/src/core/models/result.dart';
import 'package:goodbar/src/services/screen/screen_service.dart';

/// macOS implementation of ScreenService using MethodChannel.
/// 
/// Communicates with native Swift code to access NSScreen APIs
/// for retrieving display information and monitoring changes.
class MacOSScreenService implements ScreenService {
  static const _channel = MethodChannel('com.goodbar/screen_service');
  
  final AppLogger _logger;
  final _displayChangeController = StreamController<DisplayChangeEvent>.broadcast();
  
  MacOSScreenService({required AppLogger logger}) : _logger = logger.tag('MacOSScreenService') {
    _initializeEventChannel();
  }
  
  void _initializeEventChannel() {
    _channel.setMethodCallHandler(_handleMethodCall);
    _logger.d('Initialized screen service event handler');
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDisplaysChanged':
        final data = call.arguments as Map<dynamic, dynamic>;
        final event = _parseDisplayChangeEvent(data);
        _displayChangeController.add(event);
        _logger.i('Display configuration changed: ${event.changeType}');
        break;
      default:
        _logger.w('Unknown method call: ${call.method}');
    }
  }
  
  @override
  Future<Result<List<Display>, String>> getDisplays() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getDisplays');
      if (result == null) {
        return const Result.failure('No display data returned from platform');
      }
      
      final displays = result.map((data) => _parseDisplay(data as Map<dynamic, dynamic>)).toList();
      _logger.d('Retrieved ${displays.length} displays');
      return Result.success(displays);
    } on PlatformException catch (e) {
      _logger.e('Failed to get displays', e);
      return Result.failure(e.message ?? 'Platform error getting displays');
    } catch (e) {
      _logger.e('Unexpected error getting displays', e);
      return Result.failure('Unexpected error: $e');
    }
  }
  
  @override
  Future<Result<Display, String>> getDisplay(String displayId) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDisplay',
        {'displayId': displayId},
      );
      
      if (result == null) {
        return Result.failure('Display $displayId not found');
      }
      
      final display = _parseDisplay(result);
      _logger.d('Retrieved display $displayId');
      return Result.success(display);
    } on PlatformException catch (e) {
      _logger.e('Failed to get display $displayId', e);
      return Result.failure(e.message ?? 'Platform error getting display');
    } catch (e) {
      _logger.e('Unexpected error getting display $displayId', e);
      return Result.failure('Unexpected error: $e');
    }
  }
  
  @override
  Future<Result<Display, String>> getPrimaryDisplay() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getPrimaryDisplay');
      if (result == null) {
        return const Result.failure('No primary display found');
      }
      
      final display = _parseDisplay(result);
      _logger.d('Retrieved primary display ${display.id}');
      return Result.success(display);
    } on PlatformException catch (e) {
      _logger.e('Failed to get primary display', e);
      return Result.failure(e.message ?? 'Platform error getting primary display');
    } catch (e) {
      _logger.e('Unexpected error getting primary display', e);
      return Result.failure('Unexpected error: $e');
    }
  }
  
  @override
  Stream<DisplayChangeEvent> get displayChanges => _displayChangeController.stream;
  
  @override
  void dispose() {
    _displayChangeController.close();
    _channel.setMethodCallHandler(null);
    _logger.d('Disposed screen service');
  }
  
  Display _parseDisplay(Map<dynamic, dynamic> data) {
    final boundsMap = data['bounds'] as Map<dynamic, dynamic>;
    final workAreaMap = data['workArea'] as Map<dynamic, dynamic>;
    
    return Display(
      id: data['id'] as String,
      bounds: Rectangle(
        x: (boundsMap['x'] as num).toDouble(),
        y: (boundsMap['y'] as num).toDouble(),
        width: (boundsMap['width'] as num).toDouble(),
        height: (boundsMap['height'] as num).toDouble(),
      ),
      workArea: Rectangle(
        x: (workAreaMap['x'] as num).toDouble(),
        y: (workAreaMap['y'] as num).toDouble(),
        width: (workAreaMap['width'] as num).toDouble(),
        height: (workAreaMap['height'] as num).toDouble(),
      ),
      scaleFactor: (data['scaleFactor'] as num).toDouble(),
      isPrimary: data['isPrimary'] as bool,
    );
  }
  
  DisplayChangeEvent _parseDisplayChangeEvent(Map<dynamic, dynamic> data) {
    final displaysList = data['displays'] as List<dynamic>;
    final displays = displaysList.map((d) => _parseDisplay(d as Map<dynamic, dynamic>)).toList();
    
    return DisplayChangeEvent(
      displays: displays,
      changeType: data['changeType'] as String,
      timestamp: DateTime.now(),
    );
  }
}