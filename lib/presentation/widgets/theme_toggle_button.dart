import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/theme_bloc.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) => BlocConsumer<ThemeBloc, ThemeState>(
    listenWhen: (_, state) => state.error != null,
    listener: (context, state) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.error!))),
    builder: (context, state) => IconButton(
      tooltip: state.dark ? 'Switch to light mode' : 'Switch to dark mode',
      icon: Icon(
        state.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      ),
      onPressed: state.busy
          ? null
          : () => context.read<ThemeBloc>().add(ThemeChanged(!state.dark)),
    ),
  );
}
