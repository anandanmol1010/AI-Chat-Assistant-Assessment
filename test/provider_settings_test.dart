import 'package:ai_chat_assistant/data/datasources/history_database.dart';
import 'package:ai_chat_assistant/data/repositories/local_settings_repository.dart';
import 'package:ai_chat_assistant/domain/entities/provider_config.dart';
import 'package:ai_chat_assistant/domain/usecases/provider_settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saves settings with a separate key and removes it on keyless switch',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const vault = FlutterSecureStorage();
      sqfliteFfiInit();
      final db = await openHistoryDatabase(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final repository = LocalSettingsRepository(db, vault);

      const original = ProviderConfig(
        protocol: ProviderProtocol.gemini,
        name: 'Gemini test',
        baseUrl: 'https://example.test/v1beta',
        model: 'gemini-test',
        apiKey: 'test-fixture-key',
      );
      expect((await SaveProvider(repository)(original)).isRight(), isTrue);
      final row = (await db.query('provider_settings')).single;
      expect(row.values, isNot(contains(original.apiKey)));
      expect(await vault.read(key: row['key_ref'] as String), original.apiKey);
      final restored = (await LocalSettingsRepository(
        db,
        vault,
      ).load()).getOrElse((_) => throw StateError('Provider unavailable'));
      expect(restored?.apiKey, original.apiKey);
      expect(restored?.model, original.model);

      const local = ProviderConfig(
        protocol: ProviderProtocol.compatible,
        name: 'Local model',
        baseUrl: 'http://localhost:1234/v1',
        model: 'local-model',
        apiKey: '',
      );
      expect((await SaveProvider(repository)(local)).isRight(), isTrue);
      expect(await vault.readAll(), isEmpty);
      expect((await db.query('provider_settings')).single['key_ref'], isNull);
    },
  );

  test('rejects a credentialed HTTP endpoint', () {
    const config = ProviderConfig(
      protocol: ProviderProtocol.compatible,
      name: 'Compatible',
      baseUrl: 'http://localhost:1234/v1',
      model: 'local-model',
      apiKey: 'test-fixture-key',
    );
    expect(config.validationError, contains('HTTPS'));
  });
}
