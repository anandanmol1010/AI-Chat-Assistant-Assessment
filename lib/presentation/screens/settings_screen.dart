import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/provider_config.dart';
import '../blocs/settings_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<SettingsBloc, SettingsState>(
        listenWhen: (_, state) => state is SettingsLoaded && state.saved,
        listener: (context, _) => Navigator.pop(context, true),
        builder: (context, state) {
          final draft = state.draft;
          return Scaffold(
            appBar: AppBar(title: const Text('Provider settings')),
            body: draft == null
                ? const Center(child: CircularProgressIndicator())
                : _form(context, state, draft),
          );
        },
      );

  Widget _form(BuildContext context, SettingsState state, SettingsDraft draft) {
    final bloc = context.read<SettingsBloc>();
    final loading = state is SettingsLoading;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<ProviderProtocol>(
          key: ValueKey(draft.protocol),
          initialValue: draft.protocol,
          decoration: const InputDecoration(labelText: 'Protocol'),
          items: [
            for (final protocol in ProviderProtocol.values)
              DropdownMenuItem(value: protocol, child: Text(protocol.label)),
          ],
          onChanged: loading
              ? null
              : (protocol) {
                  if (protocol != null) bloc.add(ProtocolChanged(protocol));
                },
        ),
        _field(
          draft,
          ProviderField.name,
          draft.name,
          'Provider name',
          bloc,
          loading,
        ),
        _field(
          draft,
          ProviderField.url,
          draft.baseUrl,
          'API base URL',
          bloc,
          loading,
          keyboard: TextInputType.url,
        ),
        _field(
          draft,
          ProviderField.model,
          draft.model,
          'Model name',
          bloc,
          loading,
        ),
        _field(
          draft,
          ProviderField.key,
          draft.replacementKey,
          'API key',
          bloc,
          loading,
          obscure: true,
          hint: draft.hasSavedKey
              ? 'Leave blank to keep the key for the same URL'
              : null,
        ),
        if (draft.hasSavedKey)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: loading
                  ? null
                  : () => bloc.add(const SavedKeyCleared()),
              child: const Text('Clear saved key'),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Stream replies'),
          value: draft.streamReplies,
          onChanged: loading
              ? null
              : (value) => bloc.add(StreamRepliesChanged(value)),
        ),
        if (state case SettingsError(:final message))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
        if (loading) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: loading ? null : () => bloc.add(const ProviderSaved()),
          child: const Text('Save provider'),
        ),
      ],
    );
  }

  Widget _field(
    SettingsDraft draft,
    ProviderField field,
    String value,
    String label,
    SettingsBloc bloc,
    bool loading, {
    bool obscure = false,
    String? hint,
    TextInputType? keyboard,
  }) => Padding(
    key: ValueKey((draft.protocol, field)),
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      initialValue: value,
      onChanged: (value) => bloc.add(ProviderFieldChanged(field, value)),
      decoration: InputDecoration(labelText: label, hintText: hint),
      enabled: !loading,
      obscureText: obscure,
      autocorrect: !obscure,
      enableSuggestions: !obscure,
      keyboardType: keyboard,
    ),
  );
}
