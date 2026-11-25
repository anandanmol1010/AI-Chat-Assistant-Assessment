sealed class Failure {
  const Failure();
}

final class StorageFailure extends Failure {
  const StorageFailure();
}

final class ConfigFailure extends Failure {
  const ConfigFailure(this.message);
  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure();
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure();
}

final class AuthFailure extends Failure {
  const AuthFailure();
}

final class RateLimitFailure extends Failure {
  const RateLimitFailure();
}

final class InvalidResponseFailure extends Failure {
  const InvalidResponseFailure();
}

final class ServerFailure extends Failure {
  const ServerFailure();
}
