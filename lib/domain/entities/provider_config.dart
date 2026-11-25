enum ProviderProtocol {
  openAi('OpenAI', 'https://api.openai.com/v1'),
  gemini('Gemini', 'https://generativelanguage.googleapis.com/v1beta'),
  compatible('OpenAI-compatible', '');

  const ProviderProtocol(this.label, this.defaultUrl);
  final String label;
  final String defaultUrl;
}

class ProviderConfig {
  const ProviderConfig({
    required this.protocol,
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    this.streamReplies = true,
  });

  final ProviderProtocol protocol;
  final String name;
  final String baseUrl;
  final String model;
  final String apiKey;
  final bool streamReplies;

  String? get validationError {
    if (name.isEmpty || model.isEmpty) {
      return 'Enter a provider name and model.';
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return 'Enter an HTTP or HTTPS base URL without credentials, a query, or a fragment.';
    }
    if (protocol == ProviderProtocol.gemini &&
        !RegExp(r'^(models/)?[a-zA-Z0-9._-]+$').hasMatch(model)) {
      return 'Enter a Gemini model ID such as gemini-2.5-flash.';
    }
    if (protocol != ProviderProtocol.compatible && apiKey.isEmpty) {
      return 'Enter an API key for this provider.';
    }
    if (uri.scheme == 'http' &&
        (protocol != ProviderProtocol.compatible || apiKey.isNotEmpty)) {
      return 'Use HTTPS for credentials. HTTP is available for keyless compatible endpoints.';
    }
    if (uri.scheme == 'http' &&
        !{'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host)) {
      return 'Use HTTPS for remote hosts. HTTP is limited to local development hosts.';
    }
    return null;
  }
}
