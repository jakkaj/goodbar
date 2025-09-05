import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goodbar/src/services/screen/screen_service.dart';
import 'package:goodbar/src/services/screen/macos_screen_service.dart';
import 'package:goodbar/src/services/screen/fake_screen_service.dart';
import 'package:goodbar/src/bootstrap/logger_providers.dart';

/// Provider for the ScreenService interface
/// 
/// In production, provides MacOSScreenService.
/// Can be overridden in tests with FakeScreenService.
final screenServiceProvider = Provider<ScreenService>((ref) {
  final logger = ref.watch(loggerProvider('ScreenService'));
  return MacOSScreenService(logger: logger);
});

/// Provider for FakeScreenService specifically (for testing)
/// 
/// Only use in tests when you need to control the fake behavior
final fakeScreenServiceProvider = Provider<FakeScreenService>((ref) {
  return FakeScreenService();
});