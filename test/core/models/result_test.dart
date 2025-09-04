import 'package:flutter_test/flutter_test.dart';
import 'package:goodbar/src/core/models/result.dart';

void main() {
  group('Result', () {
    test('creates success with value', () {
      /// Purpose: Verify Result.success holds and returns the correct value
      /// Quality Contribution: Ensures our error handling foundation correctly
      /// preserves success values without corruption or type loss
      /// Acceptance Criteria: Success variant must store exact value with
      /// correct type and allow retrieval via pattern matching
      
      const testValue = 42;
      final result = Result<int, String>.success(testValue);
      
      // Verify we can extract the value
      result.when(
        success: (value) => expect(value, equals(testValue)),
        failure: (error) => fail('Should be success, not failure'),
      );
      
      // Verify type is preserved
      expect(result, isA<Result<int, String>>());
    });
    
    test('creates failure with error', () {
      /// Purpose: Verify Result.failure holds and returns error information
      /// Quality Contribution: Ensures errors are properly captured and
      /// available for handling without exceptions
      /// Acceptance Criteria: Failure variant must store error details
      /// and make them accessible through pattern matching
      
      const errorMessage = 'Something went wrong';
      final result = Result<int, String>.failure(errorMessage);
      
      // Verify we can extract the error
      result.when(
        success: (value) => fail('Should be failure, not success'),
        failure: (error) => expect(error, equals(errorMessage)),
      );
      
      // Verify type is preserved
      expect(result, isA<Result<int, String>>());
    });
    
    test('supports pattern matching with map', () {
      /// Purpose: Verify Freezed generates proper map method for transformations
      /// Quality Contribution: Enables functional composition and chaining
      /// of Result operations for cleaner error handling code
      /// Acceptance Criteria: Map method must transform success values while
      /// preserving failures, maintaining type safety throughout
      
      final successResult = Result<int, String>.success(10);
      final failureResult = Result<int, String>.failure('error');
      
      // Map over success should transform the value
      final mappedSuccess = successResult.map(
        success: (value) => Result<String, String>.success('Value: ${value.value}'),
        failure: (f) => Result<String, String>.failure(f.error),
      );
      
      mappedSuccess.when(
        success: (value) => expect(value, equals('Value: 10')),
        failure: (error) => fail('Should be success after mapping'),
      );
      
      // Map over failure should preserve the error
      final mappedFailure = failureResult.map(
        success: (s) => Result<String, String>.success('Value: ${s.value}'),
        failure: (f) => Result<String, String>.failure(f.error),
      );
      
      mappedFailure.when(
        success: (value) => fail('Should remain failure after mapping'),
        failure: (error) => expect(error, equals('error')),
      );
    });
    
    test('differentiates success from failure', () {
      /// Purpose: Ensure Result variants are properly distinguished
      /// Quality Contribution: Prevents treating errors as success values
      /// which could cause silent failures in the application
      /// Acceptance Criteria: Success and Failure must be distinct types
      /// that cannot be confused or incorrectly cast
      
      final success = Result<String, String>.success('data');
      final failure = Result<String, String>.failure('error');
      
      // Use maybeWhen to check variant type
      final isSuccessCorrect = success.maybeWhen(
        success: (_) => true,
        orElse: () => false,
      );
      expect(isSuccessCorrect, isTrue);
      
      final isFailureCorrect = failure.maybeWhen(
        failure: (_) => true,
        orElse: () => false,
      );
      expect(isFailureCorrect, isTrue);
      
      // Opposite checks should be false
      final successIsNotFailure = success.maybeWhen(
        failure: (_) => true,
        orElse: () => false,
      );
      expect(successIsNotFailure, isFalse);
      
      final failureIsNotSuccess = failure.maybeWhen(
        success: (_) => true,
        orElse: () => false,
      );
      expect(failureIsNotSuccess, isFalse);
    });
    
    test('works with different type parameters', () {
      /// Purpose: Verify Result is fully generic and works with any types
      /// Quality Contribution: Ensures Result can be used throughout the
      /// codebase with domain-specific types and error models
      /// Acceptance Criteria: Must support primitive types, custom classes,
      /// and null values in both success and error positions
      
      // Test with custom types
      final customResult = Result<List<int>, Exception>.success([1, 2, 3]);
      customResult.when(
        success: (list) => expect(list, equals([1, 2, 3])),
        failure: (e) => fail('Should be success'),
      );
      
      // Test with nullable types
      final nullableResult = Result<String?, String>.success(null);
      nullableResult.when(
        success: (value) => expect(value, isNull),
        failure: (e) => fail('Should handle null as success value'),
      );
      
      // Test with error as custom type
      final customError = Exception('Custom error');
      final errorResult = Result<int, Exception>.failure(customError);
      errorResult.when(
        success: (v) => fail('Should be failure'),
        failure: (error) => expect(error, equals(customError)),
      );
    });
  });
}