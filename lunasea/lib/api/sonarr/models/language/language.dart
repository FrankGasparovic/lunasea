import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
part 'language.g.dart';

@JsonSerializable(includeIfNull: false)
class SonarrLanguage {
  int? id;
  String? name;
  String? nameLower;
  String? isoCode;
  SonarrLanguage({this.id, this.name, this.nameLower, this.isoCode});
  @override
  String toString() => json.encode(toJson());
  factory SonarrLanguage.fromJson(Map<String, dynamic> json) =>
      _$SonarrLanguageFromJson(json);
  Map<String, dynamic> toJson() => _$SonarrLanguageToJson(this);
}
