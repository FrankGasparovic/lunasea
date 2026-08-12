import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/router/routes/sonarr.dart';

class SonarrManualImportRoute extends StatelessWidget {
  const SonarrManualImportRoute({super.key});
  static final _scaffoldKey = GlobalKey<ScaffoldState>();
  static final _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => SonarrManualImportState(context),
    builder: (context, _) => LunaScaffold(
      scaffoldKey: _scaffoldKey,
      appBar: LunaAppBar(title: 'sonarr.ManualImport'.tr()),
      bottomNavigationBar: LunaBottomActionBar(
        actions: [
          LunaButton.text(
            text: 'sonarr.Interactive'.tr(),
            icon: Icons.person_rounded,
            onTap: () {
              final path = context.read<SonarrManualImportState>().currentPath;
              if (path?.isNotEmpty ?? false)
                SonarrRoutes.MANUAL_IMPORT_DETAILS.go(
                  queryParams: {'path': path!},
                );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'sonarr.Path'.tr(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () =>
                      context.read<SonarrManualImportState>().fetchDirectories(
                        context,
                        context.read<SonarrManualImportState>().currentPath,
                      ),
                ),
              ),
              onSubmitted: (value) => context
                  .read<SonarrManualImportState>()
                  .fetchDirectories(context, value),
              onChanged: (value) =>
                  context.read<SonarrManualImportState>().currentPath = value,
            ),
          ),
          Expanded(
            child: FutureBuilder<SonarrFileSystem>(
              future: context.watch<SonarrManualImportState>().directories,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return LunaMessage.error(
                    onTap: () => context
                        .read<SonarrManualImportState>()
                        .fetchDirectories(
                          context,
                          context.read<SonarrManualImportState>().currentPath,
                        ),
                  );
                if (!snapshot.hasData) return const LunaLoader();
                final fs = snapshot.data!;
                return LunaListView(
                  controller: _scrollController,
                  children: [
                    if (fs.parent?.isNotEmpty ?? false)
                      LunaBlock(
                        title: '..',
                        body: [TextSpan(text: fs.parent)],
                        trailing: const LunaIconButton.arrow(),
                        onTap: () => context
                            .read<SonarrManualImportState>()
                            .fetchDirectories(context, fs.parent),
                      ),
                    ...(fs.directories ?? []).map(
                      (dir) => LunaBlock(
                        title: dir.name ?? LunaUI.TEXT_EMDASH,
                        body: [TextSpan(text: dir.path)],
                        trailing: const LunaIconButton.arrow(),
                        onTap: () => context
                            .read<SonarrManualImportState>()
                            .fetchDirectories(context, dir.path),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
