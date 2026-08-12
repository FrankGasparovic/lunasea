part of sonarr_commands;

Future<List<SonarrQualityDefinition>> _commandGetQualityDefinitions(
  Dio client,
) async {
  final response = await client.get('qualitydefinition');
  return (response.data as List)
      .map((e) => SonarrQualityDefinition.fromJson(e as Map<String, dynamic>))
      .toList();
}
