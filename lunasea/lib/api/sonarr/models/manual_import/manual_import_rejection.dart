import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
part 'manual_import_rejection.g.dart';

@JsonSerializable(includeIfNull: false)
class SonarrManualImportRejection {
  String? reason;
  String? type;
  SonarrManualImportRejection({this.reason, this.type});
  @override
  String toString() => json.encode(toJson());
  factory SonarrManualImportRejection.fromJson(Map<String, dynamic> json) =>
      _$SonarrManualImportRejectionFromJson(json);
  Map<String, dynamic> toJson() => _$SonarrManualImportRejectionToJson(this);
}
