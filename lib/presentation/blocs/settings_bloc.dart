import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/provider_config.dart';
import '../../domain/usecases/provider_settings.dart';

sealed class SettingsEvent {
  const SettingsEvent();
}

final class SettingsRequested extends SettingsEvent {
  const SettingsRequested();
}

final class ProviderSaved extends SettingsEvent {
  const ProviderSaved();
}

final class ProtocolChanged extends SettingsEvent {
  const ProtocolChanged(this.protocol);
  final ProviderProtocol protocol;
}

enum ProviderField { name, url, model, key }

final class ProviderFieldChanged extends SettingsEvent {
  const ProviderFieldChanged(this.field, this.value);
  final ProviderField field;
  final String value;
}

final class StreamRepliesChanged extends SettingsEvent {
  const StreamRepliesChanged(this.enabled);
  final bool enabled;
}

final class SavedKeyCleared extends SettingsEvent {
  const SavedKeyCleared();
}

class SettingsDraft {
  SettingsDraft.forProtocol(this.protocol, {this.streamReplies = true})
    : name = protocol.label,
      baseUrl = protocol.defaultUrl,
      model = '',
      replacementKey = '',
      _saved = null;

  SettingsDraft.fromConfig(ProviderConfig config)
    : protocol = config.protocol,
      name = config.name,
      baseUrl = config.baseUrl,
      model = config.model,
      streamReplies = config.streamReplies,
      replacementKey = '',
      _saved = config;

  const SettingsDraft._({
    required this.protocol,
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.replacementKey,
    required this.streamReplies,
    required this._saved,
  });

  final ProviderProtocol protocol;
  final String name;
  final String baseUrl;
  final String model;
  final String replacementKey;
  final bool streamReplies;
  final ProviderConfig? _saved;

  bool get hasSavedKey => _saved?.apiKey.isNotEmpty ?? false;

  SettingsDraft edit({
    ProviderField? field,
    String? value,
    bool? streamReplies,
    bool clearKey = false,
  }) => SettingsDraft._(
    protocol: protocol,
    name: field == ProviderField.name ? value! : name,
    baseUrl: field == ProviderField.url ? value! : baseUrl,
    model: field == ProviderField.model ? value! : model,
    replacementKey: field == ProviderField.key ? value! : replacementKey,
    streamReplies: streamReplies ?? this.streamReplies,
    saved: clearKey ? null : _saved,
  );

  ProviderConfig toConfig() {
    final url = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final enteredKey = replacementKey.trim();
    return ProviderConfig(
      protocol: protocol,
      streamReplies: streamReplies,
      name: name.trim(),
      baseUrl: url,
      model: model.trim(),
      apiKey: enteredKey.isEmpty && url == _saved?.baseUrl
          ? _saved!.apiKey
          : enteredKey,
    );
  }
}

sealed class SettingsState {
  const SettingsState(this.draft);
  final SettingsDraft? draft;
}

final class SettingsLoading extends SettingsState {
  const SettingsLoading([super.draft]);
}

final class SettingsLoaded extends SettingsState {
  const SettingsLoaded(SettingsDraft super.draft, {this.saved = false});
  final bool saved;
}

final class SettingsError extends SettingsState {
  const SettingsError(this.message, SettingsDraft super.draft);
  final String message;
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required this._load, required this._save})
    : super(const SettingsLoading()) {
    on<SettingsEvent>(_handle, transformer: sequential());
  }

  final LoadProvider _load;
  final SaveProvider _save;

  Future<void> _handle(SettingsEvent event, Emitter<SettingsState> emit) async {
    if (event is SettingsRequested) {
      emit(const SettingsLoading());
      final result = await _load();
      final defaults = SettingsDraft.forProtocol(ProviderProtocol.openAi);
      emit(
        result.match(
          (failure) => _error(failure, defaults),
          (config) => SettingsLoaded(
            config == null ? defaults : SettingsDraft.fromConfig(config),
          ),
        ),
      );
      return;
    }
    final current = state;
    final draft = current.draft;
    if (draft == null || (current is SettingsLoaded && current.saved)) return;
    switch (event) {
      case ProviderSaved():
        emit(SettingsLoading(draft));
        final result = await _save(draft.toConfig());
        emit(
          result.match(
            (failure) => _error(failure, draft),
            (_) => SettingsLoaded(draft, saved: true),
          ),
        );
      case ProtocolChanged(:final protocol):
        if (protocol != draft.protocol) {
          emit(
            SettingsLoaded(
              SettingsDraft.forProtocol(
                protocol,
                streamReplies: draft.streamReplies,
              ),
            ),
          );
        }
      case ProviderFieldChanged(:final field, :final value):
        emit(SettingsLoaded(draft.edit(field: field, value: value)));
      case StreamRepliesChanged(:final enabled):
        emit(SettingsLoaded(draft.edit(streamReplies: enabled)));
      case SavedKeyCleared():
        emit(SettingsLoaded(draft.edit(clearKey: true)));
      case SettingsRequested():
        return;
    }
  }

  SettingsError _error(Failure failure, SettingsDraft draft) => SettingsError(
    failure is ConfigFailure
        ? failure.message
        : 'Could not access provider settings. Try again.',
    draft,
  );
}
