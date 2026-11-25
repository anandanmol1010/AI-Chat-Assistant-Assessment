import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../entities/provider_config.dart';
import '../repositories/settings_repository.dart';

class LoadProvider {
  const LoadProvider(this._repository);
  final SettingsRepository _repository;

  Future<Either<Failure, ProviderConfig?>> call() => _repository.load();
}

class SaveProvider {
  const SaveProvider(this._repository);
  final SettingsRepository _repository;

  Future<Either<Failure, Unit>> call(ProviderConfig config) {
    final error = config.validationError;
    if (error != null) return Future.value(Left(ConfigFailure(error)));
    return _repository.save(config);
  }
}
