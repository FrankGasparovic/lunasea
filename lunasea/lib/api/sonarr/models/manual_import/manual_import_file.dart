import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import 'package:lunasea/api/sonarr/models.dart';
part 'manual_import_file.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class SonarrManualImportFile {
  String? path;
  int? seriesId;
  int? seasonNumber;
  List<int>? episodeIds;
  SonarrEpisodeFileQuality? quality;
  List<SonarrLanguage>? languages;
  String? downloadId;
  SonarrManualImportFile({
    this.path,
    this.seriesId,
    this.seasonNumber,
    this.episodeIds,
    this.quality,
    this.languages,
    this.downloadId,
  });
  @override
  String toString() => json.encode(toJson());
  factory SonarrManualImportFile.fromJson(Map<String, dynamic> json) =>
      _$SonarrManualImportFileFromJson(json);
  Map<String, dynamic> toJson() => _$SonarrManualImportFileToJson(this);
}
