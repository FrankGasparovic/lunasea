part of sonarr_commands;

Future<List<SonarrLanguage>> _commandGetLanguages(Dio client) async {
  final response = await client.get('language');
  return (response.data as List)
      .map((e) => SonarrLanguage.fromJson(e as Map<String, dynamic>))
      .toList();
}
