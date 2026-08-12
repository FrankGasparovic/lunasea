part of sonarr_commands;

Future<List<SonarrManualImport>> _commandReprocessManualImport(
  Dio client, {
  required List<SonarrManualImportReprocess> files,
}) async {
  final response = await client.post(
    'manualimport',
    data: files.map((e) => e.toJson()).toList(),
  );
  return (response.data as List)
      .map((e) => SonarrManualImport.fromJson(e as Map<String, dynamic>))
      .toList();
}
