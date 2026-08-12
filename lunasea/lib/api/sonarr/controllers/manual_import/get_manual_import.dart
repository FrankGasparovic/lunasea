part of sonarr_commands;

Future<List<SonarrManualImport>> _commandGetManualImport(
  Dio client, {
  required String folder,
  required bool filterExistingFiles,
}) async {
  final response = await client.get(
    'manualimport',
    queryParameters: {
      'folder': folder,
      'filterExistingFiles': filterExistingFiles,
    },
  );
  return (response.data as List)
      .map((e) => SonarrManualImport.fromJson(e as Map<String, dynamic>))
      .toList();
}
