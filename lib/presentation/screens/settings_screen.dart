import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/provider_config.dart';
import '../blocs/settings_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _model = TextEditingController();
  final _key = TextEditingController();
  ProviderProtocol _protocol = ProviderProtocol.openAi;
  String _savedKey = '';
  String? _savedUrl;

  @override
  void initState() {
    super.initState();
    _name.text = _protocol.label;
    _url.text = _protocol.defaultUrl;
    context.read<SettingsBloc>().add(const SettingsRequested());
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<SettingsBloc, SettingsState>(
    listener: (context, state) {
      if (state case SettingsLoaded(:final config, :final saved)) {
        if (saved) {
          Navigator.pop(context, true);
        } else if (config != null) {
          _protocol = config.protocol;
          _name.text = config.name;
          _url.text = config.baseUrl;
          _model.text = config.model;
          _savedKey = config.apiKey;
          _savedUrl = config.baseUrl;
        }
      }
    },
    builder: (context, state) {
      final loading = state is SettingsLoading;
      return Scaffold(
        appBar: AppBar(title: const Text('Provider settings')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<ProviderProtocol>(
              key: ValueKey(_protocol),
              initialValue: _protocol,
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
                      if (protocol == null || protocol == _protocol) return;
                      setState(() {
                        _protocol = protocol;
                        _name.text = protocol.label;
                        _url.text = protocol.defaultUrl;
                        _model.clear();
                        _key.clear();
                        _savedKey = '';
                      });
                    },
            ),
            _field(_name, 'Provider name', loading),
            _field(_url, 'API base URL', loading, keyboard: TextInputType.url),
            _field(_model, 'Model name', loading),
            _field(
              _key,
              'API key',
              loading,
              obscure: true,
              hint: _savedKey.isNotEmpty
                  ? 'Leave blank to keep the key for the same URL'
                  : null,
            ),
            if (_savedKey.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() => _savedKey = ''),
                  child: const Text('Clear saved key'),
                ),
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
              onPressed: loading ? null : _save,
              child: const Text('Save provider'),
            ),
          ],
        ),
      );
    },
  );

  Widget _field(
    TextEditingController controller,
    String label,
    bool loading, {
    bool obscure = false,
    String? hint,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
      enabled: !loading,
      obscureText: obscure,
      autocorrect: !obscure,
      enableSuggestions: !obscure,
      keyboardType: keyboard,
    ),
  );

  void _save() {
    final url = _url.text.trim().replaceFirst(RegExp(r'/+$'), '');
    context.read<SettingsBloc>().add(
      ProviderSaved(
        ProviderConfig(
          protocol: _protocol,
          name: _name.text.trim(),
          baseUrl: url,
          model: _model.text.trim(),
          apiKey: _key.text.trim().isEmpty && url == _savedUrl
              ? _savedKey
              : _key.text.trim(),
        ),
      ),
    );
  }
}
