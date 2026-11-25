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
  const ProviderSaved(this.config);
  final ProviderConfig config;
}

sealed class SettingsState {
  const SettingsState();
}

final class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

final class SettingsLoaded extends SettingsState {
  const SettingsLoaded(this.config, {this.saved = false});
  final ProviderConfig? config;
  final bool saved;
}

final class SettingsError extends SettingsState {
  const SettingsError(this.message);
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
    emit(const SettingsLoading());
    switch (event) {
      case SettingsRequested():
        final result = await _load();
        emit(result.match(_error, SettingsLoaded.new));
      case ProviderSaved(:final config):
        final result = await _save(config);
        emit(result.match(_error, (_) => SettingsLoaded(config, saved: true)));
    }
  }

  SettingsError _error(Failure failure) => SettingsError(
    failure is ConfigFailure
        ? failure.message
        : 'Could not access provider settings. Try again.',
  );
}
