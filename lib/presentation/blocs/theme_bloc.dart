import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/theme_preferences.dart';

sealed class ThemeEvent {
  const ThemeEvent();
}

final class ThemeRequested extends ThemeEvent {
  const ThemeRequested();
}

final class ThemeChanged extends ThemeEvent {
  const ThemeChanged(this.dark);
  final bool dark;
}

class ThemeState {
  const ThemeState({this.dark = false, this.busy = false, this.error});
  final bool dark;
  final bool busy;
  final String? error;
}

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc(this._preferences) : super(const ThemeState(busy: true)) {
    on<ThemeEvent>(_handle, transformer: sequential());
  }
  final ThemePreferences _preferences;

  Future<void> _handle(ThemeEvent event, Emitter<ThemeState> emit) async {
    final previous = state.dark;
    switch (event) {
      case ThemeRequested():
        final loaded = await _preferences.loadDarkMode();
        emit(
          loaded.match(
            (_) => ThemeState(
              dark: previous,
              error: 'Could not load the appearance preference.',
            ),
            (dark) => ThemeState(dark: dark),
          ),
        );
      case ThemeChanged(:final dark):
        if (dark == previous) return;
        emit(ThemeState(dark: previous, busy: true));
        final saved = await _preferences.saveDarkMode(dark);
        emit(
          saved.match(
            (_) => ThemeState(
              dark: previous,
              error: 'Could not save the appearance preference.',
            ),
            (_) => ThemeState(dark: dark),
          ),
        );
    }
  }
}
