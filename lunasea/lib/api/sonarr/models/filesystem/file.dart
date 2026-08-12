import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
part 'file.g.dart';

@JsonSerializable(includeIfNull: false)
class SonarrFileSystemFile {
  String? name;
  String? path;
  int? size;
  SonarrFileSystemFile({this.name, this.path, this.size});
  @override
  String toString() => json.encode(toJson());
  factory SonarrFileSystemFile.fromJson(Map<String, dynamic> json) =>
      _$SonarrFileSystemFileFromJson(json);
  Map<String, dynamic> toJson() => _$SonarrFileSystemFileToJson(this);
}
