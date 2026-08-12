import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import 'package:lunasea/api/sonarr/models.dart';
part 'manual_import.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class SonarrManualImport {
  String? path;
  String? relativePath;
  String? folderName;
  String? name;
  int? size;
  SonarrSeries? series;
  int? seasonNumber;
  List<SonarrEpisode>? episodes;
  SonarrEpisodeFileQuality? quality;
  List<SonarrLanguage>? languages;
  int? qualityWeight;
  String? downloadId;
  List<SonarrManualImportRejection>? rejections;
  int? id;
  SonarrManualImport({
    this.path,
    this.relativePath,
    this.folderName,
    this.name,
    this.size,
    this.series,
    this.seasonNumber,
    this.episodes,
    this.quality,
    this.languages,
    this.qualityWeight,
    this.downloadId,
    this.rejections,
    this.id,
  });
  @override
  String toString() => json.encode(toJson());
  factory SonarrManualImport.fromJson(Map<String, dynamic> json) =>
      _$SonarrManualImportFromJson(json);
  Map<String, dynamic> toJson() => _$SonarrManualImportToJson(this);
}
