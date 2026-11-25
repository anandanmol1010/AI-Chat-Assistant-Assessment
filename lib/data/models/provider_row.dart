import '../../domain/entities/provider_config.dart';

class ProviderRow {
  const ProviderRow(this.config, this.keyRef);

  factory ProviderRow.fromMap(Map<String, Object?> map, String apiKey) =>
      ProviderRow(
        ProviderConfig(
          protocol: ProviderProtocol.values.byName(map['protocol'] as String),
          name: map['provider_name'] as String,
          baseUrl: map['base_url'] as String,
          model: map['model'] as String,
          apiKey: apiKey,
        ),
        map['key_ref'] as String?,
      );

  final ProviderConfig config;
  final String? keyRef;

  Map<String, Object?> toMap() => {
    'id': 1,
    'provider_name': config.name,
    'protocol': config.protocol.name,
    'base_url': config.baseUrl,
    'model': config.model,
    'key_ref': keyRef,
  };
}
