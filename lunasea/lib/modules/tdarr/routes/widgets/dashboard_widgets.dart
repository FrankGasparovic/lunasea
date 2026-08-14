import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tdarr.dart';

double? normalizeTdarrProgress(double? value) {
  if (value == null || value.isNaN || value.isInfinite) return null;
  final normalized = value > 1 ? value / 100 : value;
  return normalized.clamp(0.0, 1.0);
}

enum TdarrMetric { queued, running, successful, failed }

class TdarrDashboardPage extends StatefulWidget {
  final TdarrDashboardData data;
  final ScrollController controller;
  final Future<void> Function() onRefresh;
  final Future<void> Function(TdarrTranscode) onTranscodeTap;
  final ValueChanged<TdarrMetric>? onMetricTap;

  const TdarrDashboardPage({
    super.key,
    required this.data,
    required this.controller,
    required this.onRefresh,
    required this.onTranscodeTap,
    this.onMetricTap,
  });

  @override
  State<TdarrDashboardPage> createState() => TdarrDashboardPageState();
}

class TdarrDashboardPageState extends State<TdarrDashboardPage> {
  final _transcodesKey = GlobalKey();

  Future<void> scrollToTranscodes() async {
    final target = _transcodesKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: LunaUI.ANIMATION_SPEED_SCROLLING),
      curve: Curves.easeInOutQuart,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LunaRefreshIndicator(
      context: context,
      onRefresh: widget.onRefresh,
      child: LunaListView(
        controller: widget.controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          LunaHeader(text: 'tdarr.Server'.tr()),
          _ServerCard(data: widget.data),
          LunaHeader(
            text: 'tdarr.Queue'.tr(),
            subtitle: 'tdarr.QueueSummary'.tr(
              args: [
                '${widget.data.queued}',
                '${widget.data.transcodes.length}',
              ],
            ),
          ),
          TdarrMetricGrid(
            queued: widget.data.queued,
            running: widget.data.transcodes.length,
            successful: widget.data.successful,
            failed: widget.data.failed,
            onTap: widget.onMetricTap,
          ),
          LunaHeader(key: _transcodesKey, text: 'tdarr.CurrentTranscodes'.tr()),
          if (widget.data.transcodes.isEmpty)
            LunaMessage.inList(text: 'tdarr.NoActiveTranscodes'.tr())
          else
            ...widget.data.transcodes.map(
              (item) => TdarrTranscodeTile(
                item: item,
                onTap: () => widget.onTranscodeTap(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  final TdarrDashboardData data;

  const _ServerCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final online = data.nodes.where((node) => node.online).length;
    return LunaTableCard(
      title: 'tdarr.ServerName'.tr(),
      content: [
        LunaTableContent(title: 'tdarr.Status'.tr(), body: data.status.status),
        LunaTableContent(
          title: 'tdarr.Version'.tr(),
          body: data.status.version,
        ),
        LunaTableContent(
          title: 'tdarr.Uptime'.tr(),
          body: formatTdarrUptime(data.status.uptimeSeconds),
        ),
        LunaTableContent(
          title: 'tdarr.Nodes'.tr(),
          body: '$online/${data.nodes.length} ${'tdarr.Online'.tr()}',
        ),
        LunaTableContent(
          title: 'tdarr.Workers'.tr(),
          body: '${data.transcodes.length}',
        ),
      ],
    );
  }
}

String formatTdarrUptime(int? seconds) {
  if (seconds == null) return tdarrUnavailable;
  final duration = Duration(seconds: seconds);
  return '${duration.inDays}d ${duration.inHours.remainder(24)}h '
      '${duration.inMinutes.remainder(60)}m';
}

class TdarrMetricGrid extends StatelessWidget {
  final int queued;
  final int running;
  final int successful;
  final int failed;
  final ValueChanged<TdarrMetric>? onTap;

  const TdarrMetricGrid({
    super.key,
    required this.queued,
    required this.running,
    required this.successful,
    required this.failed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        icon: Icons.schedule_rounded,
        label: 'tdarr.Queued'.tr(),
        value: queued,
        color: LunaColours.blue,
        onTap: onTap == null ? null : () => onTap!(TdarrMetric.queued),
      ),
      _MetricData(
        icon: Icons.sync_rounded,
        label: 'tdarr.Running'.tr(),
        value: running,
        color: LunaColours.accent,
        onTap: onTap == null ? null : () => onTap!(TdarrMetric.running),
      ),
      _MetricData(
        icon: Icons.check_circle_outline_rounded,
        label: 'tdarr.Successful'.tr(),
        value: successful,
        color: LunaColours.accent,
        onTap: onTap == null ? null : () => onTap!(TdarrMetric.successful),
      ),
      _MetricData(
        icon: Icons.error_outline_rounded,
        label: 'tdarr.Failed'.tr(),
        value: failed,
        color: LunaColours.red,
        onTap: onTap == null ? null : () => onTap!(TdarrMetric.failed),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: columns == 4 ? 1.75 : 1.45,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) => _MetricCard(metrics[index]),
        );
      },
    );
  }
}

class _MetricData {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback? onTap;

  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricData metric;

  const _MetricCard(this.metric);

  @override
  Widget build(BuildContext context) {
    return LunaCard(
      context: context,
      margin: EdgeInsets.zero,
      child: Semantics(
        button: metric.onTap != null,
        label: '${metric.label}: ${metric.value}',
        child: InkWell(
          onTap: metric.onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: metric.color.withValues(
                      alpha: LunaUI.OPACITY_SPLASH,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(metric.icon, color: metric.color, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${metric.value}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: metric.color,
                          fontWeight: LunaUI.FONT_WEIGHT_BOLD,
                        ),
                      ),
                      Text(
                        metric.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TdarrTranscodeTile extends StatelessWidget {
  final TdarrTranscode item;
  final VoidCallback? onTap;

  const TdarrTranscodeTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = normalizeTdarrProgress(item.percentage);
    final progressColor = progress == null
        ? LunaColours.blueGrey
        : LunaColours.accent;
    return LunaBlock(
      title: item.filename,
      titleColor: Colors.white,
      body: [
        TextSpan(
          text: '${'tdarr.Step'.tr()}: ${item.status}',
          style: const TextStyle(
            color: LunaColours.accent,
            fontWeight: LunaUI.FONT_WEIGHT_BOLD,
          ),
        ),
        TextSpan(
          text:
              '${'tdarr.Worker'.tr()}: ${item.workerType} • '
              '${'tdarr.Node'.tr()}: ${item.nodeName ?? item.nodeId}',
        ),
        TextSpan(
          text:
              '${'tdarr.ETA'.tr()}: ${item.eta} • '
              '${_percentage(item)} • ${_fps(item)}',
        ),
      ],
      bottom: LunaLinearPercentIndicator(
        percent: progress ?? 0,
        progressColor: progressColor,
      ),
      bottomHeight: LunaLinearPercentIndicator.height,
      trailing: const LunaIconButton.arrow(),
      onTap: onTap,
    );
  }

  static String _percentage(TdarrTranscode item) => item.percentage == null
      ? tdarrUnavailable
      : '${item.percentage!.toStringAsFixed(1)}%';

  static String _fps(TdarrTranscode item) =>
      '${item.fps?.toStringAsFixed(1) ?? tdarrUnavailable} FPS';
}

class TdarrTranscodeDetailsSheet extends StatefulWidget {
  final TdarrTranscode initial;

  const TdarrTranscodeDetailsSheet({super.key, required this.initial});

  static Future<void> show(BuildContext context, TdarrTranscode item) async {
    await LunaBottomModalSheet<void>().show(
      builder: (_) => TdarrTranscodeDetailsSheet(initial: item),
    );
  }

  @override
  State<TdarrTranscodeDetailsSheet> createState() =>
      _TdarrTranscodeDetailsSheetState();
}

class _TdarrTranscodeDetailsSheetState
    extends State<TdarrTranscodeDetailsSheet> {
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
    TdarrAPI? api;
    try {
      api = context.read<TdarrState>().api;
    } catch (_) {
      // Keep the details sheet renderable in isolated widget tests.
      return;
    }
    if (api == null) return;
    _refreshing = true;
    try {
      final nodes = await api.getNodes();
      TdarrTranscode? updated;
      for (final node in nodes) {
        if (node.id != widget.initial.nodeId) continue;
        for (final transcode in node.transcodes) {
          if (transcode.id == widget.initial.id) {
            updated = transcode;
            break;
          }
        }
        break;
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
      // Keep the latest successful worker details visible during transient errors.
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _transcode;
    final progress = normalizeTdarrProgress(item.percentage);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                item.filename,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _finished
                    ? 'tdarr.WorkerFinished'.tr()
                    : 'tdarr.RefreshingWorker'.tr(),
              ),
              trailing: Text(
                item.percentage == null
                    ? tdarrUnavailable
                    : '${item.percentage!.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: LunaColours.accent,
                  fontWeight: LunaUI.FONT_WEIGHT_BOLD,
                ),
              ),
            ),
            LunaLinearPercentIndicator(
              percent: progress ?? 0,
              progressColor: _finished
                  ? LunaColours.blueGrey
                  : LunaColours.accent,
            ),
            LunaTableCard(
              content: [
                LunaTableContent(title: 'tdarr.Status'.tr(), body: item.status),
                LunaTableContent(title: 'tdarr.ETA'.tr(), body: item.eta),
                LunaTableContent(title: 'tdarr.Plugin'.tr(), body: item.plugin),
                LunaTableContent(
                  title: 'tdarr.FPS'.tr(),
                  body: item.fps?.toStringAsFixed(1) ?? tdarrUnavailable,
                ),
                LunaTableContent(
                  title: 'tdarr.Node'.tr(),
                  body: item.nodeName ?? item.nodeId,
                ),
                LunaTableContent(
                  title: 'tdarr.Worker'.tr(),
                  body: item.workerType,
                ),
              ],
            ),
            LunaHeader(text: 'tdarr.Path'.tr()),
            LunaCard(
              context: context,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  item.path,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('lunasea.Close'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TdarrNodeCard extends StatelessWidget {
  final TdarrNode node;
  final bool paused;
  final bool pauseBusy;
  final int cpuLimit;
  final int gpuLimit;
  final bool Function(String workerType) isWorkerBusy;
  final Future<void> Function(bool paused)? onPauseChanged;
  final Future<void> Function(String workerType, bool increase, int limit)?
  onWorkerChanged;

  const TdarrNodeCard({
    super.key,
    required this.node,
    required this.paused,
    required this.pauseBusy,
    required this.cpuLimit,
    required this.gpuLimit,
    required this.isWorkerBusy,
    this.onPauseChanged,
    this.onWorkerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = node.online;
    return LunaCard(
      context: context,
      child: Opacity(
        opacity: enabled ? 1 : LunaUI.OPACITY_DISABLED,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Icon(
                      enabled
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: enabled ? LunaColours.accent : LunaColours.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          enabled ? 'tdarr.Online'.tr() : 'tdarr.Offline'.tr(),
                          style: TextStyle(
                            color: enabled
                                ? LunaColours.accent
                                : LunaColours.red,
                            fontSize: LunaUI.FONT_SIZE_H4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pauseBusy)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: LunaLoader(size: 16, useSafeArea: false),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          paused ? 'tdarr.Paused'.tr() : 'tdarr.Active'.tr(),
                          style: TextStyle(
                            color: paused
                                ? LunaColours.orange
                                : LunaColours.accent,
                            fontSize: LunaUI.FONT_SIZE_H4,
                          ),
                        ),
                        Tooltip(
                          message: 'tdarr.PauseNode'.tr(),
                          child: Semantics(
                            label: 'tdarr.PauseNode'.tr(),
                            toggled: !paused,
                            child: LunaSwitch(
                              // The control represents whether the node is
                              // active: on means working, off means paused.
                              value: !paused,
                              onChanged: enabled && onPauseChanged != null
                                  ? (active) => onPauseChanged!(!active)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'tdarr.ActiveTranscodeWorkers'.tr(
                    args: ['${node.transcodes.length}'],
                  ),
                  style: const TextStyle(color: LunaColours.grey),
                ),
              ),
              _WorkerRow(
                label: 'tdarr.CPUTranscode'.tr(),
                workerType: 'transcodecpu',
                limit: cpuLimit,
                enabled: enabled,
                busy: isWorkerBusy('transcodecpu'),
                onChanged: onWorkerChanged,
              ),
              _WorkerRow(
                label: 'tdarr.GPUTranscode'.tr(),
                workerType: 'transcodegpu',
                limit: gpuLimit,
                enabled: enabled,
                busy: isWorkerBusy('transcodegpu'),
                onChanged: onWorkerChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerRow extends StatelessWidget {
  final String label;
  final String workerType;
  final int limit;
  final bool enabled;
  final bool busy;
  final Future<void> Function(String workerType, bool increase, int limit)?
  onChanged;

  const _WorkerRow({
    required this.label,
    required this.workerType,
    required this.limit,
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: $limit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'tdarr.DecreaseWorkers'.tr(args: [label]),
          onPressed: !enabled || busy || limit <= 0 || onChanged == null
              ? null
              : () => onChanged!(workerType, false, limit),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        if (busy)
          const SizedBox(
            width: 28,
            height: 28,
            child: LunaLoader(size: 16, useSafeArea: false),
          )
        else
          IconButton(
            tooltip: 'tdarr.IncreaseWorkers'.tr(args: [label]),
            onPressed: !enabled || onChanged == null
                ? null
                : () => onChanged!(workerType, true, limit),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
      ],
    );
  }
}
