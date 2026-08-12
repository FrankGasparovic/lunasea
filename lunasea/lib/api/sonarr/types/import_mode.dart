part of sonarr_types;

enum SonarrImportMode {
  COPY('copy'),
  MOVE('move');

  final String value;
  const SonarrImportMode(this.value);
}
