/// Typed exceptions thrown by data sources before mapping to [Failure].
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ServerException extends AppException {
  const ServerException([super.message = 'Server error']);
}

final class AuthException extends AppException {
  const AuthException([super.message = 'Authentication error']);
}

final class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Not found']);
}

final class ValidationException extends AppException {
  const ValidationException(super.message);
}

final class PendingVerificationException extends AppException {
  const PendingVerificationException([
    super.message = 'Account awaiting admin verification',
  ]);
}
