part of sonarr_commands;

Future<SonarrFileSystem> _commandGetFileSystem(
  Dio client, {
  String? path,
  bool? includeFiles,
}) async {
  final response = await client.get(
    'filesystem',
    queryParameters: {
      if (path != null && path.isNotEmpty) 'path': path,
      if (includeFiles != null) 'includeFiles': includeFiles,
    },
  );
  return SonarrFileSystem.fromJson(response.data);
}
