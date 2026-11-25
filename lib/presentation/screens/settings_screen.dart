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
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _form(context, state, draft),
                    ),
                  ),
            bottomNavigationBar: draft == null
                ? null
                : _saveBar(context, state),
          );
        },
      );

  Widget _saveBar(BuildContext context, SettingsState state) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final saving = state is SettingsLoading;
    return SafeArea(
      top: false,
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state case SettingsError(:final message)) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: saving
                      ? null
                      : () => context.read<SettingsBloc>().add(
                          const ProviderSaved(),
                        ),
                  child: Text(saving ? 'Saving provider' : 'Save provider'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, SettingsState state, SettingsDraft draft) {
    final bloc = context.read<SettingsBloc>();
    final loading = state is SettingsLoading;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        if (state.profiles.isNotEmpty) ...[
          _SettingsSection(
            title: 'Profiles',
            children: [
              DropdownButtonFormField<int>(
                key: ValueKey(draft.profileId),
                isExpanded: true,
                initialValue: draft.profileId,
                hint: const Text('New provider profile'),
                decoration: const InputDecoration(
                  labelText: 'Provider profiles',
                ),
                items: [
                  for (final profile in state.profiles)
                    DropdownMenuItem(
                      value: profile.id,
                      child: Text(
                        profile.active
                            ? '${profile.name} (active)'
                            : profile.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: loading
                    ? null
                    : (id) {
                        if (id != null) bloc.add(ProviderProfileSelected(id));
                      },
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: loading || draft.profileId == null
                      ? null
                      : () => bloc.add(const ProviderProfileCreated()),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New profile'),
                ),
              ),
            ],
          ),
          const Divider(height: 36),
        ],
        _SettingsSection(
          title: 'Connection',
          children: [
            DropdownButtonFormField<ProviderProtocol>(
              key: ValueKey((draft.profileId, draft.protocol)),
              isExpanded: true,
              initialValue: draft.protocol,
              decoration: const InputDecoration(labelText: 'Protocol'),
              items: [
                for (final protocol in ProviderProtocol.values)
                  DropdownMenuItem(
                    value: protocol,
                    child: Text(protocol.label),
                  ),
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
              ProviderField.key,
              draft.replacementKey,
              'API key',
              bloc,
              loading,
              obscure: true,
              hint: draft.hasSavedKey
                  ? 'Leave blank to keep the saved key'
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
          ],
        ),
        const Divider(height: 36),
        _SettingsSection(
          title: 'Response',
          children: [
            _field(
              draft,
              ProviderField.model,
              draft.model,
              'Model name',
              bloc,
              loading,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Stream replies'),
              subtitle: const Text('Show text as the provider generates it.'),
              value: draft.streamReplies,
              onChanged: loading
                  ? null
                  : (value) => bloc.add(StreamRepliesChanged(value)),
            ),
          ],
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
    key: ValueKey((draft.profileId, draft.protocol, field)),
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = UnderlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: false,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: line,
          enabledBorder: line,
          disabledBorder: line,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
