import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/widgets/pages/invalid_route.dart';

class SonarrManualImportDetailsRoute extends StatelessWidget {
  final String? path;
  const SonarrManualImportDetailsRoute({super.key, required this.path});
  static final _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    if (path?.isEmpty ?? true)
      return InvalidRoutePage(
        title: 'sonarr.ManualImport'.tr(),
        message: 'sonarr.DirectoryNotFound'.tr(),
      );
    return ChangeNotifierProvider(
      create: (context) => SonarrManualImportDetailsState(context, path: path!),
      builder: (context, _) => LunaScaffold(
        scaffoldKey: _scaffoldKey,
        appBar: LunaAppBar(title: 'sonarr.ManualImport'.tr()),
        body: FutureBuilder<List<SonarrManualImport>>(
          future: context.watch<SonarrManualImportDetailsState>().imports,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return LunaMessage.error(
                onTap: () => context
                    .read<SonarrManualImportDetailsState>()
                    .fetch(context),
              );
            if (!snapshot.hasData) return const LunaLoader();
            if (snapshot.data!.isEmpty)
              return LunaMessage(text: 'sonarr.NoFilesFound'.tr());
            return _ImportsList(items: snapshot.data!);
          },
        ),
        bottomNavigationBar: _ImportActions(),
      ),
    );
  }
}

class _ImportActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<SonarrManualImportDetailsState>();
    return FutureBuilder<List<SonarrManualImport>>(
      future: state.imports,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final selectedItems = state.selectedItems(items);
        final selectedSeries = state.selectedSeries(items);
        return LunaBottomActionBar(
          actions: [
            LunaButton.text(
              text: state.areAllSelected(items)
                  ? 'sonarr.DeselectAll'.tr()
                  : 'sonarr.SelectAll'.tr(),
              icon: state.areAllSelected(items)
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
              onTap: snapshot.hasData
                  ? () => state.toggleAll(snapshot.data!)
                  : null,
            ),
            LunaButton.text(
              text: 'sonarr.Series'.tr(),
              icon: Icons.tv_rounded,
              onTap: selectedItems.isEmpty
                  ? null
                  : () => _selectSeries(context, selectedItems),
            ),
            LunaButton.text(
              text: 'sonarr.Season'.tr(),
              icon: Icons.featured_play_list_rounded,
              onTap: selectedSeries == null
                  ? null
                  : () => _selectSeason(context, selectedItems, selectedSeries),
            ),
            LunaButton.text(
              text: state.importMode == SonarrImportMode.COPY
                  ? 'sonarr.Copy'.tr()
                  : 'sonarr.Move'.tr(),
              icon: Icons.drive_file_move_rounded,
              onTap: state.toggleImportMode,
            ),
            LunaButton.text(
              text: 'sonarr.Import'.tr(),
              icon: Icons.download_done_rounded,
              onTap: state.canSubmit(items)
                  ? () async {
                      final state = context
                          .read<SonarrManualImportDetailsState>();
                      final imports = await state.imports!;
                      if (await state.submit(context, imports) &&
                          context.mounted)
                        Navigator.of(context).pop();
                    }
                  : null,
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectSeries(
    BuildContext context,
    List<SonarrManualImport> items,
  ) async {
    final selected = await _showSeriesDialog(context);
    if (selected == null || !context.mounted) return;
    for (final item in items) {
      item.series = selected;
      item.seasonNumber = null;
      item.episodes = [];
    }
    await context.read<SonarrManualImportDetailsState>().reprocessItems(
      context,
      items,
    );
  }

  Future<void> _selectSeason(
    BuildContext context,
    List<SonarrManualImport> items,
    SonarrSeries series,
  ) async {
    final selected = await _showSeasonDialog(context, series);
    if (selected == null || !context.mounted) return;
    for (final item in items) {
      if (item.seasonNumber != selected) item.episodes = [];
      item.seasonNumber = selected;
    }
    await context.read<SonarrManualImportDetailsState>().reprocessItems(
      context,
      items,
    );
  }
}

Future<SonarrSeries?> _showSeriesDialog(BuildContext context) async {
  final series =
      ((await context.read<SonarrState>().series)?.values.toList() ?? [])..sort(
        (a, b) => (a.sortTitle ?? a.title ?? '').compareTo(
          b.sortTitle ?? b.title ?? '',
        ),
      );
  var query = '';
  return showDialog<SonarrSeries>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) {
        final normalizedQuery = query.toLowerCase();
        final matches = series.where((item) {
          final titles = [
            item.title,
            item.sortTitle,
            ...?item.alternateTitles?.map((title) => title.title),
          ];
          return titles.whereType<String>().any(
            (title) => title.toLowerCase().contains(normalizedQuery),
          );
        }).toList();
        return AlertDialog(
          title: Text('sonarr.SelectSeries'.tr()),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'lunasea.SearchTextBar'.tr(),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) => update(() => query = value),
                ),
                const SizedBox(height: LunaUI.DEFAULT_MARGIN_SIZE),
                Expanded(
                  child: ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final item = matches[index];
                      return ListTile(
                        title: Text(item.title ?? LunaUI.TEXT_EMDASH),
                        subtitle: item.year == null
                            ? null
                            : Text(item.year.toString()),
                        onTap: () => Navigator.pop(dialogContext, item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('lunasea.Cancel'.tr()),
            ),
          ],
        );
      },
    ),
  );
}

Future<int?> _showSeasonDialog(BuildContext context, SonarrSeries series) =>
    showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('sonarr.SelectSeason'.tr()),
        children: (series.seasons ?? [])
            .map(
              (season) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, season.seasonNumber),
                child: Text('${season.seasonNumber}'),
              ),
            )
            .toList(),
      ),
    );

class _ImportsList extends StatelessWidget {
  final List<SonarrManualImport> items;
  const _ImportsList({required this.items});
  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => _ImportTile(item: items[index]),
  );
}

class _ImportTile extends StatefulWidget {
  final SonarrManualImport item;
  const _ImportTile({required this.item});
  @override
  State<_ImportTile> createState() => _ImportTileState();
}

class _ImportTileState extends State<_ImportTile> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final state = context.watch<SonarrManualImportDetailsState>();
    return ExpansionTile(
      title: Text(item.relativePath ?? item.path ?? LunaUI.TEXT_EMDASH),
      subtitle: Text(
        '${item.series?.title ?? 'sonarr.NoSeriesSelected'.tr()} • ${item.quality?.quality?.name ?? 'sonarr.NoQualitySelected'.tr()}',
      ),
      leading: Checkbox(
        value: state.selected.contains(item.id),
        onChanged: item.id != null && (item.path?.isNotEmpty ?? false)
            ? (value) => state.setSelected(item.id!, value!)
            : null,
      ),
      children: [
        ListTile(
          title: Text('sonarr.Series'.tr()),
          subtitle: Text(item.series?.title ?? LunaUI.TEXT_EMDASH),
          onTap: () => _selectSeries(context),
        ),
        ListTile(
          title: Text('sonarr.Season'.tr()),
          subtitle: Text(item.seasonNumber?.toString() ?? LunaUI.TEXT_EMDASH),
          onTap: item.series == null ? null : () => _selectSeason(context),
        ),
        ListTile(
          title: Text('sonarr.Episodes'.tr()),
          subtitle: Text(
            (item.episodes ?? []).map((e) => e.episodeNumber).join(', '),
          ),
          onTap: item.series == null || item.seasonNumber == null
              ? null
              : () => _selectEpisodes(context),
        ),
        ListTile(
          title: Text('sonarr.Quality'.tr()),
          subtitle: Text(item.quality?.quality?.name ?? LunaUI.TEXT_EMDASH),
          onTap: () => _selectQuality(context),
        ),
        ListTile(
          title: Text('sonarr.Languages'.tr()),
          subtitle: Text((item.languages ?? []).map((e) => e.name).join(', ')),
          onTap: () => _selectLanguages(context),
        ),
        ListTile(
          title: Text('sonarr.Rejections'.tr()),
          subtitle: Text(
            (item.rejections ?? [])
                .map((r) => r.reason)
                .whereType<String>()
                .join('\n'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectSeries(BuildContext context) async {
    final series =
        ((await context.read<SonarrState>().series)?.values.toList() ?? [])
          ..sort(
            (a, b) => (a.sortTitle ?? a.title ?? '').compareTo(
              b.sortTitle ?? b.title ?? '',
            ),
          );
    var query = '';
    final selected = await showDialog<SonarrSeries>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final normalizedQuery = query.toLowerCase();
          final matches = series.where((item) {
            final titles = [
              item.title,
              item.sortTitle,
              ...?item.alternateTitles?.map((title) => title.title),
            ];
            return titles.whereType<String>().any(
              (title) => title.toLowerCase().contains(normalizedQuery),
            );
          }).toList();
          return AlertDialog(
            title: Text('sonarr.SelectSeries'.tr()),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'lunasea.SearchTextBar'.tr(),
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => update(() => query = value),
                  ),
                  const SizedBox(height: LunaUI.DEFAULT_MARGIN_SIZE),
                  Expanded(
                    child: ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final item = matches[index];
                        final title = item.title ?? LunaUI.TEXT_EMDASH;
                        return ListTile(
                          title: Text(title),
                          subtitle: item.year == null
                              ? null
                              : Text(item.year.toString()),
                          onTap: () => Navigator.pop(dialogContext, item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('lunasea.Cancel'.tr()),
              ),
            ],
          );
        },
      ),
    );
    if (selected != null) {
      widget.item.series = selected;
      widget.item.seasonNumber = null;
      widget.item.episodes = [];
      await context.read<SonarrManualImportDetailsState>().reprocess(
        context,
        widget.item,
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _selectSeason(BuildContext context) async {
    final seasons = widget.item.series!.seasons ?? [];
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('sonarr.SelectSeason'.tr()),
        children: seasons
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, s.seasonNumber),
                child: Text('${s.seasonNumber}'),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      widget.item.seasonNumber = selected;
      widget.item.episodes = [];
      await context.read<SonarrManualImportDetailsState>().reprocess(
        context,
        widget.item,
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _selectEpisodes(BuildContext context) async {
    final episodes = await context.read<SonarrState>().api!.episode.getMulti(
      seriesId: widget.item.series!.id,
      seasonNumber: widget.item.seasonNumber,
    );
    final chosen = <int>{
      ...(widget.item.episodes ?? []).map((e) => e.id!).toSet(),
    };
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('sonarr.SelectEpisodes'.tr()),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: episodes
                  .map(
                    (e) => CheckboxListTile(
                      value: chosen.contains(e.id),
                      title: Text('${e.episodeNumber}: ${e.title}'),
                      onChanged: (v) => update(
                        () => v! ? chosen.add(e.id!) : chosen.remove(e.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => update(() => chosen.clear()),
              child: Text('lunasea.Clear'.tr()),
            ),
            TextButton(
              onPressed: () => update(
                () => chosen.addAll(episodes.map((episode) => episode.id!)),
              ),
              child: Text('sonarr.SelectAll'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('lunasea.Cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                widget.item.episodes = episodes
                    .where((e) => chosen.contains(e.id))
                    .toList();
                Navigator.pop(context, true);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await context.read<SonarrManualImportDetailsState>().reprocess(
      context,
      widget.item,
    );
    if (mounted) setState(() {});
  }

  Future<void> _selectQuality(BuildContext context) async {
    final qualities = await context
        .read<SonarrState>()
        .api!
        .qualityDefinition
        .getAll();
    if (!mounted) return;
    final selected = await showDialog<SonarrEpisodeFileQualityQuality>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('sonarr.SelectQuality'.tr()),
        children: qualities
            .where((q) => q.quality != null)
            .map(
              (q) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, q.quality),
                child: Text(q.quality!.name ?? LunaUI.TEXT_EMDASH),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      widget.item.quality = SonarrEpisodeFileQuality(quality: selected);
      await context.read<SonarrManualImportDetailsState>().reprocess(
        context,
        widget.item,
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _selectLanguages(BuildContext context) async {
    final languages = await context.read<SonarrState>().api!.language.getAll();
    final selected = <int>{
      ...(widget.item.languages ?? []).map((e) => e.id!).toSet(),
    };
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('sonarr.SelectLanguages'.tr()),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              children: languages
                  .map(
                    (l) => CheckboxListTile(
                      value: selected.contains(l.id),
                      title: Text(l.name ?? LunaUI.TEXT_EMDASH),
                      onChanged: (v) => update(
                        () => v! ? selected.add(l.id!) : selected.remove(l.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('lunasea.Cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                widget.item.languages = languages
                    .where((l) => selected.contains(l.id))
                    .toList();
                Navigator.pop(context, true);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await context.read<SonarrManualImportDetailsState>().reprocess(
      context,
      widget.item,
    );
    if (mounted) setState(() {});
  }
}
