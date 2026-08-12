import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import 'package:lunasea/api/sonarr/models.dart';
part 'manual_import_reprocess.g.dart';

/// The editable portion of a scan result. Parsed fields are retained so Sonarr
/// can continue to apply its original release parsing during reprocessing.
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class SonarrManualImportReprocess {
  int? id;
  String? path;
  int? seriesId;
  int? seasonNumber;
  List<int>? episodeIds;
  SonarrEpisodeFileQuality? quality;
  List<SonarrLanguage>? languages;
  String? downloadId;
  SonarrManualImportReprocess({
    this.id,
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
  factory SonarrManualImportReprocess.fromJson(Map<String, dynamic> json) =>
      _$SonarrManualImportReprocessFromJson(json);
  Map<String, dynamic> toJson() => _$SonarrManualImportReprocessToJson(this);
}
