part of sonarr_commands;

class SonarrControllerLanguage {
  final Dio _client;
  SonarrControllerLanguage(this._client);
  Future<List<SonarrLanguage>> getAll() => _commandGetLanguages(_client);
}
