import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';
import '../entities/provider_config.dart';

abstract interface class SettingsRepository {
  Future<Either<Failure, ProviderConfig?>> load();
  Future<Either<Failure, Unit>> save(ProviderConfig config);
}
