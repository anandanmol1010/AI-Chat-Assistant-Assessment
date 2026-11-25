import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/errors/failure.dart';
import '../../domain/entities/provider_config.dart';
import '../../domain/entities/provider_profile.dart';
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

final class ProviderProfileSelected extends SettingsEvent {
  const ProviderProfileSelected(this.id);
  final int id;
}

final class ProviderProfileCreated extends SettingsEvent {
  const ProviderProfileCreated();
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
  SettingsDraft.forProtocol(
    this.protocol, {
    this.streamReplies = true,
    this.profileId,
  }) : name = protocol.label,
       baseUrl = protocol.defaultUrl,
       model = '',
       replacementKey = '',
       _saved = null;

  SettingsDraft.fromConfig(ProviderConfig config, {required this.profileId})
    : protocol = config.protocol,
      name = config.name,
      baseUrl = config.baseUrl,
      model = config.model,
      streamReplies = config.streamReplies,
      replacementKey = '',
      _saved = config;

  const SettingsDraft._({
    required this.protocol,
    required this.profileId,
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.replacementKey,
    required this.streamReplies,
    required this._saved,
  });

  final ProviderProtocol protocol;
  final int? profileId;
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
    profileId: profileId,
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
  const SettingsState(this.draft, this.profiles);
  final SettingsDraft? draft;
  final List<ProviderProfile> profiles;
}

final class SettingsLoading extends SettingsState {
  const SettingsLoading([super.draft, super.profiles = const []]);
}

final class SettingsLoaded extends SettingsState {
  const SettingsLoaded(
    SettingsDraft super.draft,
    super.profiles, {
    this.saved = false,
  });
  final bool saved;
}

final class SettingsError extends SettingsState {
  const SettingsError(this.message, SettingsDraft super.draft, super.profiles);
  final String message;
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required this._load, required this._profiles})
    : super(const SettingsLoading()) {
    on<SettingsEvent>(_handle, transformer: sequential());
  }

  final LoadProvider _load;
  final ManageProviderProfiles _profiles;

  Future<void> _handle(SettingsEvent event, Emitter<SettingsState> emit) async {
    if (event is SettingsRequested) {
      await _reload(emit);
      return;
    }
    final current = state;
    final draft = current.draft;
    final profiles = current.profiles;
    if (draft == null || (current is SettingsLoaded && current.saved)) return;
    switch (event) {
      case ProviderSaved():
        emit(SettingsLoading(draft, profiles));
        final result = await _profiles.save(
          draft.toConfig(),
          id: draft.profileId,
        );
        emit(
          result.match(
            (failure) => _error(failure, draft, profiles),
            (_) => SettingsLoaded(draft, profiles, saved: true),
          ),
        );
      case ProviderProfileSelected(:final id):
        if (id == draft.profileId) return;
        emit(SettingsLoading(draft, profiles));
        final result = await _profiles.activate(id);
        await result.match(
          (failure) async => emit(_error(failure, draft, profiles)),
          (_) => _reload(emit),
        );
      case ProviderProfileCreated():
        emit(
          SettingsLoaded(
            SettingsDraft.forProtocol(ProviderProtocol.openAi),
            profiles,
          ),
        );
      case ProtocolChanged(:final protocol):
        if (protocol != draft.protocol) {
          emit(
            SettingsLoaded(
              SettingsDraft.forProtocol(
                protocol,
                streamReplies: draft.streamReplies,
                profileId: draft.profileId,
              ),
              profiles,
            ),
          );
        }
      case ProviderFieldChanged(:final field, :final value):
        emit(SettingsLoaded(draft.edit(field: field, value: value), profiles));
      case StreamRepliesChanged(:final enabled):
        emit(SettingsLoaded(draft.edit(streamReplies: enabled), profiles));
      case SavedKeyCleared():
        emit(SettingsLoaded(draft.edit(clearKey: true), profiles));
      case SettingsRequested():
        return;
    }
  }

  Future<void> _reload(Emitter<SettingsState> emit) async {
    emit(const SettingsLoading());
    final defaults = SettingsDraft.forProtocol(ProviderProtocol.openAi);
    final listed = await _profiles.list();
    await listed.match(
      (failure) async => emit(_error(failure, defaults, const [])),
      (items) async {
        final profiles = List<ProviderProfile>.unmodifiable(items);
        final active = profiles.where((item) => item.active).singleOrNull;
        final loaded = await _load();
        emit(
          loaded.match(
            (failure) => _error(failure, defaults, profiles),
            (config) => SettingsLoaded(
              config == null
                  ? defaults
                  : SettingsDraft.fromConfig(config, profileId: active?.id),
              profiles,
            ),
          ),
        );
      },
    );
  }

  SettingsError _error(
    Failure failure,
    SettingsDraft draft,
    List<ProviderProfile> profiles,
  ) => SettingsError(
    failure is ConfigFailure
        ? failure.message
        : 'Could not access provider settings. Try again.',
    draft,
    profiles,
  );
}
