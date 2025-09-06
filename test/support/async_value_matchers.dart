import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generic matchers for AsyncValue states
/// 
/// These matchers provide readable assertions for any provider state testing.
/// They are domain-agnostic and can be used across all features.
/// 
/// Usage:
/// ```dart
/// expect(state, isLoading<List<MyModel>>());
/// expect(state, isData<String>((s) => s.isNotEmpty));
/// expect(state, isError<int>());
/// ```

/// Matches AsyncLoading state
Matcher isLoading<T>() => isA<AsyncLoading<T>>();

/// Matches AsyncData state with a predicate on the value
Matcher isData<T>(dynamic Function(T) predicate) => 
    isA<AsyncData<T>>().having(
      (d) => predicate(d.value), 
      'predicate matches', 
      isTrue,
    );

/// Matches AsyncData state with exact value equality
Matcher isDataWithValue<T>(T expected) => 
    isA<AsyncData<T>>().having(
      (d) => d.value, 
      'value', 
      equals(expected),
    );

/// Matches any AsyncError state
Matcher isError<T>() => isA<AsyncError<T>>();

/// Matches AsyncError state with specific error type
Matcher isErrorWithType<T, E>() => 
    isA<AsyncError<T>>().having(
      (e) => e.error, 
      'error', 
      isA<E>(),
    );

/// Matches AsyncError state with error message containing text
Matcher isErrorWithMessage<T>(String message) => 
    isA<AsyncError<T>>().having(
      (e) => e.error.toString(), 
      'error message', 
      contains(message),
    );