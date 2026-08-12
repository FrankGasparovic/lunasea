part of sonarr_commands;

class SonarrControllerFileSystem {
  final Dio _client;
  SonarrControllerFileSystem(this._client);

  Future<SonarrFileSystem> get({String? path, bool? includeFiles}) =>
      _commandGetFileSystem(_client, path: path, includeFiles: includeFiles);
}
