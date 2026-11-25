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
