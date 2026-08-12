/// Utilities for validating module connection details before creating clients.
class LunaConnectionDetails {
  const LunaConnectionDetails._();

  /// A module host must be an absolute HTTP(S) URL with a host component.
  static bool isValidHost(String host) {
    if (host.trim() != host || host.isEmpty) return false;
    final uri = Uri.tryParse(host);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority &&
        uri.host.isNotEmpty;
  }

  static bool hasApiKey(String apiKey) => apiKey.trim().isNotEmpty;

  static bool isReady({required String host, required String apiKey}) =>
      isValidHost(host) && hasApiKey(apiKey);
}
