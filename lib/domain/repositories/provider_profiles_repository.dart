import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../entities/provider_config.dart';
import '../entities/provider_profile.dart';

abstract interface class ProviderProfilesRepository {
  Future<Either<Failure, List<ProviderProfile>>> listProfiles();
  Future<Either<Failure, Unit>> activateProfile(int id);
  Future<Either<Failure, Unit>> saveProfile(ProviderConfig config, {int? id});
}
