import 'package:freezed_annotation/freezed_annotation.dart';

part 'result.freezed.dart';

/// A type that represents either a successful value or a failure.
/// 
/// This is used throughout the application to handle errors explicitly
/// without throwing exceptions. All fallible operations return a Result.
/// 
/// Example usage:
/// ```dart
/// Result<User, String> getUser(int id) {
///   try {
///     final user = database.find(id);
///     return Result.success(user);
///   } catch (e) {
///     return Result.failure('Failed to get user: $e');
///   }
/// }
/// ```
@freezed
sealed class Result<T, E> with _$Result<T, E> {
  /// Creates a successful result containing [value].
  const factory Result.success(T value) = _Success<T, E>;
  
  /// Creates a failed result containing [error].
  const factory Result.failure(E error) = _Failure<T, E>;
}