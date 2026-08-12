import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import 'package:lunasea/api/sonarr/models.dart';

part 'filesystem.g.dart';

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class SonarrFileSystem {
  String? parent;
  List<SonarrFileSystemDirectory>? directories;
  List<SonarrFileSystemFile>? files;
  SonarrFileSystem({this.parent, this.directories, this.files});
  @override
  String toString() => json.encode(toJson());
  factory SonarrFileSystem.fromJson(Map<String, dynamic> json) =>
      _$SonarrFileSystemFromJson(json);
  Map<String, dynamic> toJson() => _$SonarrFileSystemToJson(this);
}
