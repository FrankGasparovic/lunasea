part of sonarr_commands;

class SonarrControllerQualityDefinition {
  final Dio _client;
  SonarrControllerQualityDefinition(this._client);
  Future<List<SonarrQualityDefinition>> getAll() =>
      _commandGetQualityDefinitions(_client);
}
