/// Typed exception hierarchy and Result wrapper for clean error handling
/// across the Data, Domain, and UI layers.
sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

class NetworkException extends AppException {
  const NetworkException([
    super.message =
        'Unable to reach the server. Please check your internet connection and try again.',
    Object? cause,
  ]) : super(code: 'NETWORK_ERROR', cause: cause);
}

class TimeoutException extends AppException {
  const TimeoutException([
    super.message = 'The request timed out. Please try again.',
    Object? cause,
  ]) : super(code: 'TIMEOUT_ERROR', cause: cause);
}

class ServerException extends AppException {
  const ServerException(
    super.message, {
    this.statusCode,
    super.cause,
  }) : super(code: 'SERVER_ERROR');

  final int? statusCode;
}

class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
  }) : super(code: 'VALIDATION_ERROR');

  final Map<String, String> fieldErrors;
}

class NotFoundException extends AppException {
  const NotFoundException([
    super.message = 'The requested resource could not be found.',
  ]) : super(code: 'NOT_FOUND');
}

/// Functional Result type so Repositories never leak raw uncaught exceptions
/// into ViewModels unexpectedly.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        Failure<T>() => null,
      };

  AppException? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(:final error) => error,
      };

  R when<R>({
    required R Function(T data) success,
    required R Function(AppException error) failure,
  }) {
    return switch (this) {
      Success<T>(:final data) => success(data),
      Failure<T>(:final error) => failure(error),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppException error;
}
