import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tdarr.dart';

class TdarrRoute extends StatefulWidget {
  const TdarrRoute({super.key});

  @override
  State<TdarrRoute> createState() => _TdarrRouteState();
}

class _TdarrRouteState extends State<TdarrRoute> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _pageController = LunaPageController();
  final _dashboardKey = GlobalKey<TdarrDashboardPageState>();
  final _queueKey = GlobalKey<TdarrQueuePageState>();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
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
    if (refresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted || !context.read<TdarrState>().enabled) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (_activePage == TdarrDestination.queue) {
      await _queueKey.currentState?.refresh();
      return;
    }
    await context.read<TdarrState>().refresh();
  }

  TdarrDestination get _activePage =>
      TdarrDestination.values[((_pageController.hasClients
                  ? _pageController.page?.round()
                  : null) ??
              _pageController.initialPage)
          .clamp(0, TdarrDestination.values.length - 1)
          .toInt()];

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<TdarrState>().enabled;
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
        pageController: enabled ? _pageController : null,
        scrollControllers: enabled
            ? TdarrNavigationBar.scrollControllers
            : null,
        actions: [
          LunaIconButton(icon: Icons.refresh_rounded, onPressed: _refresh),
        ],
      ),
      bottomNavigationBar: enabled
          ? TdarrNavigationBar(pageController: _pageController)
          : null,
      body: _body(enabled),
    );
  }

  Widget _body(bool enabled) {
    if (!enabled) {
      return LunaMessage.moduleNotEnabled(context: context, module: 'Tdarr');
    }
    final state = context.watch<TdarrState>();
    final future = state.dashboard;
    if (future == null) return const LunaLoader();
    return FutureBuilder<TdarrDashboardData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const LunaLoader();
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return LunaMessage.error(onTap: _refresh);
        }
        final data = snapshot.data;
        if (data == null) return LunaMessage.error(onTap: _refresh);
        return LunaPageView(
          controller: _pageController,
          physics: const PageScrollPhysics(),
          children: [
            TdarrDashboardPage(
              key: _dashboardKey,
              data: data,
              controller: TdarrNavigationBar.scrollControllers[0],
              onRefresh: _refresh,
              onTranscodeTap: (item) =>
                  TdarrTranscodeDetailsSheet.show(context, item),
              onMetricTap: _onMetricTap,
            ),
            TdarrNodesPage(
              nodes: data.nodes,
              controller: TdarrNavigationBar.scrollControllers[1],
              onRefresh: _refresh,
              onPauseChanged: _setNodePaused,
              onWorkerChanged: _setWorkerLimit,
            ),
            TdarrQueuePage(
              key: _queueKey,
              controller: TdarrNavigationBar.scrollControllers[2],
            ),
            TdarrReportsPage(
              reports: data.completedReports,
              totalCount: data.successful,
              table: 'table2',
              failed: false,
              controller: TdarrNavigationBar.scrollControllers[3],
            ),
            TdarrReportsPage(
              reports: data.failedReports,
              totalCount: data.failed,
              table: 'table3',
              failed: true,
              controller: TdarrNavigationBar.scrollControllers[4],
            ),
          ],
        );
      },
    );
  }

  Future<void> _onMetricTap(TdarrMetric metric) async {
    if (metric == TdarrMetric.running) {
      await _dashboardKey.currentState?.scrollToTranscodes();
      return;
    }
    final destination = switch (metric) {
      TdarrMetric.queued => TdarrDestination.queue,
      TdarrMetric.successful => TdarrDestination.completed,
      TdarrMetric.failed => TdarrDestination.failed,
      TdarrMetric.running => TdarrDestination.dashboard,
    };
    if (!_pageController.hasClients) return;
    await _pageController.animateToPage(
      destination.index,
      duration: const Duration(milliseconds: LunaUI.ANIMATION_SPEED),
      curve: Curves.easeInOut,
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
        showLunaErrorSnackBar(
          title: 'tdarr.NodeUpdateFailed'.tr(),
          error: error,
        );
      }
    }
  }

  Future<void> _setWorkerLimit(
    TdarrNode node,
    String workerType,
    bool increase,
    int limit,
  ) async {
    try {
      await context.read<TdarrState>().alterWorkerLimit(
        nodeId: node.id,
        workerType: workerType,
        increase: increase,
        currentLimit: limit,
      );
    } catch (error, stack) {
      LunaLogger().error('Failed to alter Tdarr worker limit', error, stack);
      if (mounted) {
        showLunaErrorSnackBar(
          title: 'tdarr.WorkerUpdateFailed'.tr(),
          error: error,
        );
      }
    }
  }
}

enum TdarrDestination { dashboard, nodes, queue, completed, failed }

class TdarrNodesPage extends StatelessWidget {
  final List<TdarrNode> nodes;
  final ScrollController controller;
  final Future<void> Function() onRefresh;
  final Future<void> Function(TdarrNode node, bool paused) onPauseChanged;
  final Future<void> Function(
    TdarrNode node,
    String workerType,
    bool increase,
    int limit,
  )
  onWorkerChanged;

  const TdarrNodesPage({
    super.key,
    required this.nodes,
    required this.controller,
    required this.onRefresh,
    required this.onPauseChanged,
    required this.onWorkerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TdarrState>();
    return LunaRefreshIndicator(
      context: context,
      onRefresh: onRefresh,
      child: LunaListView(
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          LunaHeader(
            text: 'tdarr.Nodes'.tr(),
            subtitle: 'tdarr.NodesSummary'.tr(args: ['${nodes.length}']),
          ),
          if (nodes.isEmpty)
            LunaMessage.inList(text: 'tdarr.NoNodesFound'.tr())
          else
            ...nodes.map(
              (node) => TdarrNodeCard(
                node: node,
                paused: state.nodePaused(node),
                pauseBusy: state.isUpdatingNode(node.id),
                cpuLimit: state.workerLimit(
                  node.id,
                  'transcodecpu',
                  node.cpuLimit,
                ),
                gpuLimit: state.workerLimit(
                  node.id,
                  'transcodegpu',
                  node.gpuLimit,
                ),
                isWorkerBusy: (type) => state.isMutating(node.id, type),
                onPauseChanged: (paused) => onPauseChanged(node, paused),
                onWorkerChanged: (type, increase, limit) =>
                    onWorkerChanged(node, type, increase, limit),
              ),
            ),
        ],
      ),
    );
  }
}
