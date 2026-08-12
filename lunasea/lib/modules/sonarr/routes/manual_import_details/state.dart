import 'package:flutter/material.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/vendor.dart';

class SonarrManualImportDetailsState extends ChangeNotifier {
  SonarrManualImportDetailsState(BuildContext context, {required this.path}) {
    importMode = SonarrDatabase.MANUAL_IMPORT_MODE.read() == 'move'
        ? SonarrImportMode.MOVE
        : SonarrImportMode.COPY;
    fetch(context);
  }
  final String path;
  Future<List<SonarrManualImport>>? imports;
  final Set<int> selected = {};
  SonarrImportMode importMode = SonarrImportMode.COPY;

  void toggleImportMode() {
    importMode = importMode == SonarrImportMode.COPY
        ? SonarrImportMode.MOVE
        : SonarrImportMode.COPY;
    SonarrDatabase.MANUAL_IMPORT_MODE.update(importMode.value);
    notifyListeners();
  }

  void setSelected(int id, bool value) {
    value ? selected.add(id) : selected.remove(id);
    notifyListeners();
  }

  void toggleAll(List<SonarrManualImport> items) {
    final validIds = items.where(isValid).map((item) => item.id!).toSet();
    if (validIds.isNotEmpty && validIds.every(selected.contains)) {
      selected.removeAll(validIds);
    } else {
      selected.addAll(validIds);
    }
    notifyListeners();
  }

  bool areAllValidSelected(List<SonarrManualImport> items) {
    final validIds = items.where(isValid).map((item) => item.id!).toSet();
    return validIds.isNotEmpty && validIds.every(selected.contains);
  }

  void fetch(BuildContext context) {
    if (context.read<SonarrState>().enabled) {
      imports = context.read<SonarrState>().api!.manualImport.get(
        folder: path,
        filterExistingFiles: true,
      );
    }
    notifyListeners();
  }

  bool isValid(SonarrManualImport item) =>
      item.id != null &&
      (item.path?.isNotEmpty ?? false) &&
      item.series?.id != null &&
      item.seasonNumber != null &&
      (item.episodes?.isNotEmpty ?? false) &&
      item.quality?.quality?.id != null &&
      (item.languages?.isNotEmpty ?? false);

  SonarrManualImportFile? buildFile(SonarrManualImport item) {
    if (!isValid(item)) return null;
    return SonarrManualImportFile(
      path: item.path,
      seriesId: item.series!.id,
      seasonNumber: item.seasonNumber,
      episodeIds: item.episodes!.map((e) => e.id!).toList(),
      quality: item.quality,
      languages: item.languages,
      downloadId: item.downloadId,
    );
  }

  Future<SonarrManualImport> reprocess(
    BuildContext context,
    SonarrManualImport item,
  ) async {
    final result = await context
        .read<SonarrState>()
        .api!
        .manualImport
        .reprocess(
          files: [
            SonarrManualImportReprocess(
              id: item.id,
              path: item.path,
              seriesId: item.series?.id,
              seasonNumber: item.seasonNumber,
              episodeIds: item.episodes
                  ?.where((e) => e.id != null)
                  .map((e) => e.id!)
                  .toList(),
              quality: item.quality,
              languages: item.languages,
              downloadId: item.downloadId,
            ),
          ],
        );
    if (result.isNotEmpty) {
      final updated = result.first;
      // Sonarr's reprocess resource deliberately does not include `series` in
      // its response; it returns only `seriesId`. Retain the selected series
      // instead of overwriting it with null from deserialization.
      item.seasonNumber = updated.seasonNumber;
      item.episodes = updated.episodes;
      item.quality = updated.quality;
      item.languages = updated.languages;
      item.rejections = updated.rejections;
      if (!isValid(item) && item.id != null) selected.remove(item.id);
    }
    notifyListeners();
    return item;
  }

  Future<bool> submit(
    BuildContext context,
    List<SonarrManualImport> items,
  ) async {
    final files = items
        .where((item) => selected.contains(item.id))
        .map(buildFile)
        .whereType<SonarrManualImportFile>()
        .toList();
    if (files.isEmpty) return false;
    await context.read<SonarrState>().api!.command.manualImport(
      files: files,
      importMode: importMode,
    );
    return true;
  }
}
