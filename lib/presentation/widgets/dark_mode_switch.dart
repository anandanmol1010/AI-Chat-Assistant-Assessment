import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/theme_bloc.dart';

class DarkModeSwitch extends StatelessWidget {
  const DarkModeSwitch({super.key});

  @override
  Widget build(BuildContext context) => BlocConsumer<ThemeBloc, ThemeState>(
    listenWhen: (_, state) => state.error != null,
    listener: (context, state) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.error!))),
    builder: (context, state) => SwitchListTile(
      title: const Text('Dark mode'),
      secondary: const Icon(Icons.dark_mode_outlined),
      value: state.dark,
      onChanged: state.busy
          ? null
          : (dark) => context.read<ThemeBloc>().add(ThemeChanged(dark)),
    ),
  );
}
