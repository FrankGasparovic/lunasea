import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/datetime.dart';
import 'package:lunasea/modules/tdarr.dart';
import 'package:lunasea/router/routes/tdarr.dart';

class TdarrRoute extends StatefulWidget {
  const TdarrRoute({super.key});

  @override
  State<TdarrRoute> createState() => _TdarrRouteState();
}

class _TdarrRouteState extends State<TdarrRoute>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _timer;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(length: 5, vsync: this);
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabs.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling(refresh: true);
    } else {
      _timer?.cancel();
    }
  }

  void _startPolling({bool refresh = false}) {
    _timer?.cancel();
    if (refresh)
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted || !context.read<TdarrState>().enabled) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    try {
      await context.read<TdarrState>().refresh();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      module: LunaModule.TDARR,
      drawer: LunaDrawer(page: LunaModule.TDARR.key),
      appBar: LunaAppBar.dropdown(
        title: LunaModule.TDARR.title,
        useDrawer: true,
        profiles: LunaProfile.list
            .where((key) => LunaBox.profiles.read(key)?.tdarrEnabled ?? false)
            .toList(),
        actions: [
          LunaIconButton(icon: Icons.refresh_rounded, onPressed: _refresh),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(text: 'tdarr.Dashboard'.tr()),
            Tab(text: 'tdarr.Nodes'.tr()),
            const Tab(text: 'Queue'),
            Tab(text: 'tdarr.Completed'.tr()),
            Tab(text: 'tdarr.Failed'.tr()),
          ],
        ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (!context.watch<TdarrState>().enabled) {
      return LunaMessage.moduleNotEnabled(context: context, module: 'Tdarr');
    }
    return FutureBuilder<TdarrDashboardData>(
      future: context.watch<TdarrState>().dashboard,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return LunaMessage(
            text: '${snapshot.error}',
            buttonText: 'lunasea.TryAgain'.tr(),
            onTap: _refresh,
          );
        }
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        return TabBarView(
          controller: _tabs,
          children: [
            _refreshable(_overview(data)),
            _refreshable(_nodes(data.nodes)),
            const _TdarrStatusTableList(table: 'table1', queue: true),
            _reports(data.completedReports, table: 'table2'),
            _reports(data.failedReports, table: 'table3', failed: true),
          ],
        );
      },
    );
  }

  Widget _refreshable(Widget child) =>
      RefreshIndicator(onRefresh: _refresh, child: child);

  Widget _overview(TdarrDashboardData data) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _section('tdarr.Server'.tr()),
        LunaBlock(
          title: 'Tdarr Server',
          body: [
            TextSpan(text: 'Status: ${data.status.status}'),
            TextSpan(text: 'Version: ${data.status.version}'),
            TextSpan(text: 'Uptime: ${_uptime(data.status.uptimeSeconds)}'),
            TextSpan(
              text:
                  'Nodes: ${data.nodes.where((node) => node.online).length}/${data.nodes.length} online • ${data.transcodes.length} active',
            ),
          ],
          leading: const Icon(Icons.dns_rounded, color: LunaColours.accent),
        ),
        _section('tdarr.Queue'.tr()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _count('tdarr.Queued'.tr(), data.queued),
              _count('tdarr.Running'.tr(), data.transcodes.length),
              _count('tdarr.Successful'.tr(), data.successful),
              _count('tdarr.Failed'.tr(), data.failed),
            ],
          ),
        ),
        _section('tdarr.CurrentTranscodes'.tr()),
        if (data.transcodes.isEmpty)
          LunaMessage.inList(text: 'tdarr.NoActiveTranscodes'.tr()),
        ...data.transcodes.map(_transcode),
      ],
    );
  }

  Widget _count(String label, int count) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Column(
          children: [
            Text('$count', style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );

  Widget _transcode(TdarrTranscode item) {
    final progress = item.percentage == null
        ? null
        : (item.percentage! > 1 ? item.percentage! / 100 : item.percentage!)
              .clamp(0.0, 1.0);
    return LunaBlock(
      title: item.filename,
      body: [
        TextSpan(text: 'Status: ${item.status} • ${item.workerType}'),
        TextSpan(text: 'Node: ${item.nodeName ?? item.nodeId}'),
        TextSpan(
          text:
              'ETA: ${item.eta} • ${_percentage(item)} • ${item.fps?.toStringAsFixed(1) ?? tdarrUnavailable} FPS',
        ),
        TextSpan(text: 'Plugin: ${item.plugin}'),
        TextSpan(text: 'Path: ${item.path}'),
      ],
      bottom: progress == null
          ? null
          : LinearProgressIndicator(value: progress),
      bottomHeight: 8,
      onTap: () => _showTranscodeDetails(item),
    );
  }

  String _percentage(TdarrTranscode item) => item.percentage == null
      ? tdarrUnavailable
      : '${item.percentage!.toStringAsFixed(1)}%';

  Future<void> _showTranscodeDetails(TdarrTranscode item) => showDialog<void>(
    context: context,
    builder: (_) => _TdarrTranscodeDetailsDialog(initial: item),
  );

  Widget _nodes(List<TdarrNode> nodes) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (nodes.isEmpty) LunaMessage.inList(text: 'tdarr.NoNodesFound'.tr()),
        ...nodes.map((node) => _node(node)),
      ],
    );
  }

  Widget _node(TdarrNode node) {
    final state = context.watch<TdarrState>();
    return Card(
      margin: LunaUI.MARGIN_H_DEFAULT_V_HALF,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: node.online ? LunaColours.accent : LunaColours.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      node.online ? 'tdarr.Online'.tr() : 'tdarr.Offline'.tr(),
                    ),
                    SizedBox(
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Paused'),
                          Checkbox(
                            value: state.nodePaused(node),
                            onChanged:
                                !node.online || state.isUpdatingNode(node.id)
                                ? null
                                : (value) =>
                                      _setNodePaused(node, value ?? false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'tdarr.ActiveTranscodeWorkers'.tr(
                args: ['${node.transcodes.length}'],
              ),
            ),
            _workerControls(
              node,
              'tdarr.CPUTranscode'.tr(),
              'transcodecpu',
              state.workerLimit(node.id, 'transcodecpu', node.cpuLimit),
            ),
            _workerControls(
              node,
              'tdarr.GPUTranscode'.tr(),
              'transcodegpu',
              state.workerLimit(node.id, 'transcodegpu', node.gpuLimit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setNodePaused(TdarrNode node, bool paused) async {
    try {
      await context.read<TdarrState>().setNodePaused(node, paused);
    } catch (error, stack) {
      LunaLogger().error(
        'Failed to update Tdarr node pause state',
        error,
        stack,
      );
      if (mounted) {
        showLunaErrorSnackBar(title: 'Failed to update node', error: error);
      }
    }
  }

  Widget _workerControls(TdarrNode node, String label, String type, int limit) {
    final busy = context.watch<TdarrState>().isMutating(node.id, type);
    return Row(
      children: [
        Expanded(child: Text('$label: $limit')),
        IconButton(
          tooltip: 'Decrease $label workers',
          onPressed: !node.online || busy || limit <= 0
              ? null
              : () => _mutate(node, type, false, limit),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        if (busy)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            tooltip: 'Increase $label workers',
            onPressed: !node.online
                ? null
                : () => _mutate(node, type, true, limit),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
      ],
    );
  }

  Future<void> _mutate(
    TdarrNode node,
    String type,
    bool increase,
    int limit,
  ) async {
    try {
      await context.read<TdarrState>().alterWorkerLimit(
        nodeId: node.id,
        workerType: type,
        increase: increase,
        currentLimit: limit,
      );
    } catch (error, stack) {
      LunaLogger().error('Failed to alter Tdarr worker limit', error, stack);
      if (mounted)
        showLunaErrorSnackBar(
          title: 'tdarr.WorkerUpdateFailed'.tr(),
          error: error,
        );
    }
  }

  Widget _reports(
    List<TdarrJobReport> reports, {
    required String table,
    bool failed = false,
  }) {
    return _TdarrReportList(
      key: ValueKey(failed),
      reports: reports,
      table: table,
      failed: failed,
    );
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  String _uptime(int? seconds) {
    if (seconds == null) return tdarrUnavailable;
    final duration = Duration(seconds: seconds);
    return '${duration.inDays}d ${duration.inHours.remainder(24)}h ${duration.inMinutes.remainder(60)}m';
  }
}

class _TdarrTranscodeDetailsDialog extends StatefulWidget {
  final TdarrTranscode initial;

  const _TdarrTranscodeDetailsDialog({required this.initial});

  @override
  State<_TdarrTranscodeDetailsDialog> createState() =>
      _TdarrTranscodeDetailsDialogState();
}

class _TdarrTranscodeDetailsDialogState
    extends State<_TdarrTranscodeDetailsDialog> {
  Timer? _timer;
  late TdarrTranscode _transcode;
  bool _refreshing = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _transcode = widget.initial;
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing || _finished) return;
    final api = context.read<TdarrState>().api;
    if (api == null) return;
    _refreshing = true;
    try {
      final nodes = await api.getNodes();
      TdarrTranscode? updated;
      for (final node in nodes) {
        for (final transcode in node.transcodes) {
          if (node.id == widget.initial.nodeId &&
              transcode.id == widget.initial.id) {
            updated = transcode;
            break;
          }
        }
        if (updated != null) break;
      }
      if (!mounted) return;
      setState(() {
        if (updated == null) {
          _finished = true;
        } else {
          _transcode = updated;
        }
      });
    } catch (_) {
      // Keep showing the most recently received worker information.
    } finally {
      _refreshing = false;
    }
  }

  String _percentage(TdarrTranscode item) => item.percentage == null
      ? tdarrUnavailable
      : '${item.percentage!.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final item = _transcode;
    return AlertDialog(
      title: Text(item.filename),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail('Status', item.status),
              _detail('ETA', item.eta),
              _detail('Plugin', item.plugin),
              _detail('Percentage', _percentage(item)),
              _detail('FPS', item.fps?.toStringAsFixed(1) ?? tdarrUnavailable),
              _detail('Node', item.nodeId),
              _detail('Node name', item.nodeName ?? item.nodeId),
              _detail('Worker', item.workerType),
              _detail('Path', item.path),
              const SizedBox(height: 4),
              Text(
                _finished ? 'No longer active' : 'Refreshing every second',
                style: const TextStyle(color: LunaColours.blueGrey),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('lunasea.Close'.tr()),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: LunaColours.blueGrey)),
        const SizedBox(height: 2),
        SelectableText(value),
      ],
    ),
  );
}

class _TdarrReportList extends StatefulWidget {
  final List<TdarrJobReport> reports;
  final String table;
  final bool failed;

  const _TdarrReportList({
    super.key,
    required this.reports,
    required this.table,
    required this.failed,
  });

  @override
  State<_TdarrReportList> createState() => _TdarrReportListState();
}

class _TdarrReportListState extends State<_TdarrReportList> {
  static const pageSize = 100;
  int page = 0;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  TdarrStatusTable? _searchResults;
  Object? _searchError;
  bool _searching = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _searchError = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final result = await context.read<TdarrState>().api!.getStatusTable(
          widget.table,
          search: value,
        );
        if (mounted && _searchController.text == value) {
          setState(() {
            _searchResults = result;
            _searchError = null;
            _searching = false;
          });
        }
      } catch (error) {
        if (mounted && _searchController.text == value) {
          setState(() {
            _searchError = error;
            _searching = false;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _TdarrReportList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastPage = widget.reports.isEmpty
        ? 0
        : (widget.reports.length - 1) ~/ pageSize;
    if (page > lastPage) page = lastPage;
  }

  Future<void> _requeue(TdarrJobReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('tdarr.RequeueFailedTranscode'.tr()),
        content: Text('tdarr.RequeueDescription'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('lunasea.Cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('tdarr.Requeue'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<TdarrState>().requeue(report);
      if (mounted) {
        showLunaSuccessSnackBar(
          title: 'tdarr.Requeued'.tr(),
          message: report.filename,
        );
      }
    } catch (error, stack) {
      LunaLogger().error('Failed to requeue Tdarr transcode', error, stack);
      if (mounted) {
        showLunaErrorSnackBar(title: 'tdarr.RequeueFailed'.tr(), error: error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usingSearch = _searchController.text.trim().isNotEmpty;
    final start = page * pageSize;
    final end = min(start + pageSize, widget.reports.length);
    final visible = widget.reports.skip(start).take(pageSize);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              hintText:
                  'Search all ${widget.failed ? 'failed' : 'completed'} files',
            ),
          ),
        ),
        if (_searchError != null)
          LunaMessage.inList(text: '$_searchError')
        else if (usingSearch && _searchResults != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('${_searchResults!.totalCount} matching files'),
          ),
          ..._searchResults!.entries.map(
            (entry) => LunaBlock(
              title: entry.filename,
              titleColor: widget.failed ? LunaColours.red : Colors.white,
              body: [
                TextSpan(text: entry.status),
                TextSpan(
                  text: entry.timestamp == null
                      ? tdarrUnavailable
                      : entry.timestamp!.asDateTime(),
                ),
              ],
            ),
          ),
        ] else ...[
          if (widget.reports.isEmpty)
            LunaMessage.inList(
              text: widget.failed
                  ? 'tdarr.NoFailedTranscodes'.tr()
                  : 'tdarr.NoCompletedTranscodes'.tr(),
            ),
          ...visible.map(
            (report) => LunaBlock(
              title: report.filename,
              titleColor: report.failed ? LunaColours.red : Colors.white,
              body: [
                TextSpan(text: report.status),
                TextSpan(
                  text: report.timestamp.year == 1970
                      ? tdarrUnavailable
                      : report.timestamp.asDateTime(),
                ),
              ],
              trailing: widget.failed && report.fileId.isNotEmpty
                  ? context.watch<TdarrState>().isRequeuing(report.fileId)
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: 'tdarr.Requeue'.tr(),
                            onPressed: () => _requeue(report),
                            icon: const Icon(Icons.replay_rounded),
                          )
                  : report.jobFileId.isEmpty
                  ? null
                  : const LunaIconButton.arrow(),
              onTap: report.jobFileId.isEmpty
                  ? null
                  : () => TdarrRoutes.REPORT.go(extra: report),
            ),
          ),
          if (widget.reports.length > pageSize)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'tdarr.NewerReports'.tr(),
                  onPressed: page == 0 ? null : () => setState(() => page--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('${start + 1}–$end of ${widget.reports.length}'),
                IconButton(
                  tooltip: 'tdarr.OlderReports'.tr(),
                  onPressed: end >= widget.reports.length
                      ? null
                      : () => setState(() => page++),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _TdarrStatusTableList extends StatefulWidget {
  final String table;
  final bool queue;

  const _TdarrStatusTableList({required this.table, required this.queue});

  @override
  State<_TdarrStatusTableList> createState() => _TdarrStatusTableListState();
}

class _TdarrStatusTableListState extends State<_TdarrStatusTableList> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  TdarrStatusTable? _results;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<TdarrState>().api!.getStatusTable(
        widget.table,
        search: _searchController.text,
      );
      if (mounted) setState(() => _results = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(_) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _setBumped(TdarrStatusEntry entry, bool bumped) async {
    try {
      await context.read<TdarrState>().setQueueBumped(entry, bumped);
      await _load();
    } catch (error, stack) {
      LunaLogger().error('Failed to update Tdarr queue priority', error, stack);
      if (mounted) {
        showLunaErrorSnackBar(
          title: 'Failed to update queue priority',
          error: error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                hintText: 'Search all queued files',
              ),
            ),
          ),
          if (_error != null)
            LunaMessage.inList(text: '$_error')
          else if (results != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('${results.totalCount} queued files'),
            ),
            ...results.entries.map(
              (entry) => LunaBlock(
                title: entry.filename,
                titleColor: entry.bumped ? LunaColours.accent : Colors.white,
                body: [
                  TextSpan(text: entry.status),
                  TextSpan(text: entry.bumped ? 'Bumped priority' : entry.path),
                ],
                trailing:
                    context.watch<TdarrState>().isUpdatingQueue(entry.fileId)
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        tooltip: entry.bumped ? 'Remove bump' : 'Bump priority',
                        onPressed: () => _setBumped(entry, !entry.bumped),
                        icon: Icon(
                          entry.bumped
                              ? Icons.vertical_align_bottom_rounded
                              : Icons.vertical_align_top_rounded,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
