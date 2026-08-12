import 'package:flutter/material.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/vendor.dart';

class SonarrManualImportState extends ChangeNotifier {
  SonarrManualImportState(BuildContext context) {
    fetchDirectories(context);
  }
  String? currentPath;
  Future<SonarrFileSystem>? directories;
  void fetchDirectories(BuildContext context, [String? path]) {
    currentPath = path;
    if (context.read<SonarrState>().enabled) {
      directories = context.read<SonarrState>().api!.fileSystem.get(path: path);
    }
    notifyListeners();
  }
}
