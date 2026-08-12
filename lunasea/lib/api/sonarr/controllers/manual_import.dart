part of sonarr_commands;

class SonarrControllerManualImport {
  final Dio _client;
  SonarrControllerManualImport(this._client);
  Future<List<SonarrManualImport>> get({
    required String folder,
    bool filterExistingFiles = true,
  }) => _commandGetManualImport(
    _client,
    folder: folder,
    filterExistingFiles: filterExistingFiles,
  );
  Future<List<SonarrManualImport>> reprocess({
    required List<SonarrManualImportReprocess> files,
  }) => _commandReprocessManualImport(_client, files: files);
}
