import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/provider_config.dart';
import '../../domain/entities/provider_profile.dart';
import '../../domain/repositories/provider_profiles_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../models/provider_row.dart';

class LocalSettingsRepository
    implements SettingsRepository, ProviderProfilesRepository {
  const LocalSettingsRepository(this._db, this._vault);

  static const _table = 'provider_settings';
  final Database _db;
  final FlutterSecureStorage _vault;

  @override
  Future<Either<Failure, ProviderConfig?>> load() => _guard(
    () => _db.transaction((transaction) async {
      final rows = await transaction.query(_table, where: 'active = 1');
      if (rows.isEmpty) return const Right(null);
      final row = rows.single;
      final ref = row['key_ref'] as String?;
      final key = ref == null ? '' : await _vault.read(key: ref);
      return Right(ProviderRow.fromMap(row, key ?? '').config);
    }),
  );

  @override
  Future<Either<Failure, List<ProviderProfile>>> listProfiles() =>
      _guard(() async {
        final rows = await _db.query(
          _table,
          columns: ['id', 'provider_name', 'active'],
          orderBy: 'id',
        );
        return Right([
          for (final row in rows)
            ProviderProfile(
              id: row['id'] as int,
              name: row['provider_name'] as String,
              active: row['active'] == 1,
            ),
        ]);
      });

  @override
  Future<Either<Failure, Unit>> activateProfile(int id) => _guard(
    () => _db.transaction((transaction) async {
      if (await _find(transaction, id) == null) {
        return const Left(
          ConfigFailure('This provider profile is no longer available.'),
        );
      }
      await _deactivate(transaction);
      await transaction.update(
        _table,
        {'active': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      return const Right(unit);
    }),
  );

  @override
  Future<Either<Failure, Unit>> saveProfile(
    ProviderConfig config, {
    int? id,
  }) async {
    final ref = config.apiKey.isEmpty
        ? null
        : 'provider-key-${const Uuid().v4()}';
    String? previous;
    final result = await _guard<Unit>(() async {
      if (ref != null) await _vault.write(key: ref, value: config.apiKey);
      return _db.transaction((transaction) async {
        final existing = id == null ? null : await _find(transaction, id);
        if (id != null && existing == null) {
          return const Left(
            ConfigFailure('This provider profile is no longer available.'),
          );
        }
        final values = ProviderRow(config, ref).toMap();
        await _deactivate(transaction);
        if (existing == null) {
          await transaction.insert(_table, values);
        } else {
          await transaction.update(
            _table,
            values,
            where: 'id = ?',
            whereArgs: [existing['id']],
          );
          previous = existing['key_ref'] as String?;
        }
        return const Right(unit);
      });
    });
    await _discard(result.isRight() ? previous : ref);
    return result;
  }

  Future<Map<String, Object?>?> _find(Transaction transaction, int id) async =>
      (await transaction.query(
        _table,
        where: 'id = ?',
        whereArgs: [id],
      )).singleOrNull;

  Future<int> _deactivate(Transaction transaction) =>
      transaction.update(_table, {'active': 0}, where: 'active = 1');

  Future<Either<Failure, T>> _guard<T>(
    Future<Either<Failure, T>> Function() operation,
  ) async {
    try {
      return await operation();
    } on DatabaseException {
      return const Left(StorageFailure());
    } on PlatformException {
      return const Left(StorageFailure());
    }
  }

  Future<void> _discard(String? ref) async {
    if (ref == null) return;
    try {
      await _vault.delete(key: ref);
    } on PlatformException {
      // Profile metadata still points to the committed key.
    }
  }
}
