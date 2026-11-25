import 'package:fpdart/fpdart.dart';

import '../../core/errors/failure.dart';

abstract interface class ThemePreferences {
  Future<Either<Failure, bool>> loadDarkMode();
  Future<Either<Failure, Unit>> saveDarkMode(bool enabled);
}
