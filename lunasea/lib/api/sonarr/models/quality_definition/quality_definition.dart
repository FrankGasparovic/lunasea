import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import 'package:lunasea/api/sonarr/models.dart';
part 'quality_definition.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class SonarrQualityDefinition {
  SonarrEpisodeFileQualityQuality? quality;
  int? weight;
  SonarrQualityDefinition({this.quality, this.weight});
  @override
  String toString() => json.encode(toJson());
  factory SonarrQualityDefinition.fromJson(Map<String, dynamic> json) =>
      _$SonarrQualityDefinitionFromJson(json);
  Map<String, dynamic> toJson() => _$SonarrQualityDefinitionToJson(this);
}
