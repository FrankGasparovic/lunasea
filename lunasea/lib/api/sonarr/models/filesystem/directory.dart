import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
part 'directory.g.dart';

@JsonSerializable(includeIfNull: false)
class SonarrFileSystemDirectory {
  String? name;
  String? path;
  SonarrFileSystemDirectory({this.name, this.path});
  @override
  String toString() => json.encode(toJson());
  factory SonarrFileSystemDirectory.fromJson(Map<String, dynamic> json) =>
      _$SonarrFileSystemDirectoryFromJson(json);
  Map<String, dynamic> toJson() => _$SonarrFileSystemDirectoryToJson(this);
}
