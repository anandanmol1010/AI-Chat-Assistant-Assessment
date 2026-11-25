import 'dart:io';

import 'package:ai_chat_assistant/data/datasources/history_database.dart';
import 'package:ai_chat_assistant/data/repositories/sqlite_theme_preferences.dart';
import 'package:ai_chat_assistant/presentation/blocs/theme_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'dark mode remains selected after reopening the database and Bloc',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'theme_preferences_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'history.sqlite');

      final first = await openHistoryDatabase(
        factory: databaseFactoryFfi,
        path: path,
      );
      final bloc = ThemeBloc(SqliteThemePreferences(first));
      try {
        final loaded = bloc.stream.firstWhere((state) => !state.busy);
        bloc.add(const ThemeRequested());
        expect((await loaded).dark, isFalse);

        final saved = bloc.stream.firstWhere(
          (state) => !state.busy && state.dark,
        );
        bloc.add(const ThemeChanged(true));
        expect((await saved).error, isNull);
      } finally {
        await bloc.close();
        await first.close();
      }

      final reopened = await openHistoryDatabase(
        factory: databaseFactoryFfi,
        path: path,
      );
      final restored = ThemeBloc(SqliteThemePreferences(reopened));
      addTearDown(reopened.close);
      addTearDown(restored.close);
      final loaded = restored.stream.firstWhere((state) => !state.busy);
      restored.add(const ThemeRequested());
      expect((await loaded).dark, isTrue);
      final light = restored.stream.firstWhere(
        (state) => !state.busy && !state.dark,
      );
      restored.add(const ThemeChanged(false));
      await light;
      expect(
        (await SqliteThemePreferences(
          reopened,
        ).loadDarkMode()).getOrElse((_) => true),
        isFalse,
      );
    },
  );
}
