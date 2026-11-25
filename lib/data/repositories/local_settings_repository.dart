import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/provider_config.dart';
import '../../domain/repositories/settings_repository.dart';
import '../models/provider_row.dart';

class LocalSettingsRepository implements SettingsRepository {
  const LocalSettingsRepository(this._db, this._vault);

  final Database _db;
  final FlutterSecureStorage _vault;

  @override
  Future<Either<Failure, ProviderConfig?>> load() async {
    try {
      final rows = await _db.query('provider_settings');
      if (rows.isEmpty) return const Right(null);
      final row = rows.single;
      final ref = row['key_ref'] as String?;
      final key = ref == null ? '' : await _vault.read(key: ref);
      if (key == null) {
        return const Left(
          ConfigFailure(
            'The saved key is unavailable. Enter it again in Settings.',
          ),
        );
      }
      return Right(ProviderRow.fromMap(row, key).config);
    } on DatabaseException {
      return const Left(StorageFailure());
    } on PlatformException {
      return const Left(StorageFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> save(ProviderConfig config) async {
    final ref = config.apiKey.isEmpty
        ? null
        : 'provider-key-${const Uuid().v4()}';
    String? previous;
    try {
      if (ref != null) await _vault.write(key: ref, value: config.apiKey);
      previous = await _db.transaction((transaction) async {
        final rows = await transaction.query(
          'provider_settings',
          columns: ['key_ref'],
        );
        await transaction.insert(
          'provider_settings',
          ProviderRow(config, ref).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return rows.singleOrNull?['key_ref'] as String?;
      });
    } on DatabaseException {
      await _discard(ref);
      return const Left(StorageFailure());
    } on PlatformException {
      await _discard(ref);
      return const Left(StorageFailure());
    }
    await _discard(previous);
    return const Right(unit);
  }

  Future<void> _discard(String? ref) async {
    if (ref == null) return;
    try {
      await _vault.delete(key: ref);
    } on PlatformException {
      // The committed row still points to the correct key.
    }
  }
}
