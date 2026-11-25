import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../entities/provider_config.dart';
import '../entities/provider_profile.dart';
import '../repositories/provider_profiles_repository.dart';
import '../repositories/settings_repository.dart';

class LoadProvider {
  const LoadProvider(this._repository);
  final SettingsRepository _repository;

  Future<Either<Failure, ProviderConfig?>> call() => _repository.load();
}

class ManageProviderProfiles {
  const ManageProviderProfiles(this._repository);
  final ProviderProfilesRepository _repository;

  Future<Either<Failure, List<ProviderProfile>>> list() =>
      _repository.listProfiles();

  Future<Either<Failure, Unit>> activate(int id) =>
      _repository.activateProfile(id);

  Future<Either<Failure, Unit>> save(ProviderConfig config, {int? id}) {
    final error = config.validationError;
    if (error != null) return Future.value(Left(ConfigFailure(error)));
    return _repository.saveProfile(config, id: id);
  }
}
