import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/errors/failure.dart';
import '../../domain/repositories/theme_preferences.dart';

class SqliteThemePreferences implements ThemePreferences {
  const SqliteThemePreferences(this._db);
  final Database _db;

  @override
  Future<Either<Failure, bool>> loadDarkMode() async {
    try {
      final rows = await _db.query('app_preferences', columns: ['dark_mode']);
      return Right(rows.firstOrNull?['dark_mode'] == 1);
    } on DatabaseException {
      return const Left(StorageFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> saveDarkMode(bool enabled) async {
    try {
      await _db.insert('app_preferences', {
        'id': 1,
        'dark_mode': enabled ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return const Right(unit);
    } on DatabaseException {
      return const Left(StorageFailure());
    }
  }
}
