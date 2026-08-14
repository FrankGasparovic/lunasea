import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/extensions/datetime.dart';
import 'package:lunasea/modules/tdarr.dart';
import 'package:lunasea/router/routes/tdarr.dart';

String tdarrResultCount({required int loaded, required int total}) {
  final shown = loaded.clamp(0, 100);
  if (total > shown) {
    return 'tdarr.ShowingResults'.tr(args: ['$shown', '$total']);
  }
  return 'tdarr.ResultsCount'.tr(args: ['$total']);
}

String truncateTdarrPath(String path, [int maxLength = 80]) {
  if (path.length <= maxLength) return path;
  return '${path.substring(0, maxLength - 1)}…';
}

class TdarrQueuePage extends StatefulWidget {
  final ScrollController controller;

  const TdarrQueuePage({super.key, required this.controller});

  @override
  State<TdarrQueuePage> createState() => TdarrQueuePageState();
}

class TdarrQueuePageState extends State<TdarrQueuePage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  TdarrStatusTable? _results;
  Object? _error;
  bool _loading = true;
  int _requestId = 0;

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

  Future<void> refresh() => _load();

  Future<void> _load() async {
    TdarrAPI? api;
    try {
      api = context.read<TdarrState>().api;
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (api == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final request = ++_requestId;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await api.getStatusTable(
        'table1',
        search: _searchController.text,
      );
      if (mounted && request == _requestId) {
        setState(() => _results = result);
      }
    } catch (error) {
      if (mounted && request == _requestId) setState(() => _error = error);
    } finally {
      if (mounted && request == _requestId) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _setBumped(TdarrStatusEntry entry) async {
    try {
      await context.read<TdarrState>().setQueueBumped(entry, !entry.bumped);
      await _load();
    } catch (error, stack) {
      LunaLogger().error('Failed to update Tdarr queue priority', error, stack);
      if (mounted) {
        showLunaErrorSnackBar(
          title: 'tdarr.QueueUpdateFailed'.tr(),
          error: error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final searching = _searchController.text.trim().isNotEmpty;
    final entries = results?.entries ?? const <TdarrStatusEntry>[];
    return LunaRefreshIndicator(
      context: context,
      onRefresh: _load,
      child: LunaListView(
        controller: widget.controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          LunaTextInputBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            labelText: 'tdarr.SearchQueued'.tr(),
            scrollController: widget.controller,
          ),
          if (_loading && results == null) const LunaLoader(size: 18),
          if (_error != null)
            LunaMessage.error(onTap: _load, useSafeArea: false)
          else if (results != null) ...[
            LunaHeader(
              text: 'tdarr.Queue'.tr(),
              subtitle: tdarrResultCount(
                loaded: entries.length,
                total: results.totalCount,
              ),
            ),
            if (entries.isEmpty)
              LunaMessage.inList(
                text: searching
                    ? 'tdarr.NoMatchingFiles'.tr()
                    : 'tdarr.NoQueuedTranscodes'.tr(),
              )
            else
              ...entries.map(
                (entry) => _TdarrQueueTile(
                  entry: entry,
                  busy: _isQueueUpdating(context, entry.fileId),
                  onBump: () => _setBumped(entry),
                ),
              ),
          ],
          if (_loading && results != null)
            const LunaLoader(size: 14, useSafeArea: false),
        ],
      ),
    );
  }

  bool _isQueueUpdating(BuildContext context, String fileId) {
    try {
      return context.watch<TdarrState>().isUpdatingQueue(fileId);
    } catch (_) {
      return false;
    }
  }
}

class _TdarrQueueTile extends StatelessWidget {
  final TdarrStatusEntry entry;
  final bool busy;
  final VoidCallback onBump;

  const _TdarrQueueTile({
    required this.entry,
    required this.busy,
    required this.onBump,
  });

  @override
  Widget build(BuildContext context) {
    return LunaBlock(
      title: entry.filename,
      titleColor: entry.bumped ? LunaColours.accent : Colors.white,
      leading: Icon(
        entry.bumped
            ? Icons.vertical_align_top_rounded
            : Icons.queue_play_next_rounded,
        color: entry.bumped ? LunaColours.accent : LunaColours.blueGrey,
      ),
      body: [
        TextSpan(
          text: entry.status,
          style: const TextStyle(fontWeight: LunaUI.FONT_WEIGHT_BOLD),
        ),
        TextSpan(text: truncateTdarrPath(entry.path)),
      ],
      trailing: busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: LunaLoader(size: 16, useSafeArea: false),
            )
          : Tooltip(
              message: entry.bumped
                  ? 'tdarr.RemoveBump'.tr()
                  : 'tdarr.BumpPriority'.tr(),
              child: LunaIconButton(
                icon: entry.bumped
                    ? Icons.vertical_align_bottom_rounded
                    : Icons.vertical_align_top_rounded,
                onPressed: onBump,
              ),
            ),
    );
  }
}

class TdarrReportsPage extends StatefulWidget {
  final List<TdarrJobReport> reports;
  final int totalCount;
  final String table;
  final bool failed;
  final ScrollController controller;

  const TdarrReportsPage({
    super.key,
    required this.reports,
    required this.totalCount,
    required this.table,
    required this.failed,
    required this.controller,
  });

  @override
  State<TdarrReportsPage> createState() => _TdarrReportsPageState();
}

class _TdarrReportsPageState extends State<TdarrReportsPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  TdarrStatusTable? _searchResults;
  Object? _searchError;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _searchError = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      TdarrAPI? api;
      try {
        api = context.read<TdarrState>().api;
      } catch (_) {
        if (mounted) {
          setState(() {
            _searchError = 'tdarr.SearchUnavailable'.tr();
            _searching = false;
          });
        }
        return;
      }
      if (api == null) {
        if (mounted) {
          setState(() {
            _searchError = 'tdarr.SearchUnavailable'.tr();
            _searching = false;
          });
        }
        return;
      }
      try {
        final result = await api.getStatusTable(widget.table, search: value);
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

  Future<void> _requeue(TdarrJobReport report) async {
    var confirmed = false;
    await LunaDialog.dialog(
      context: context,
      title: 'tdarr.RequeueFailedTranscode'.tr(),
      contentPadding: LunaDialog.textDialogContentPadding(),
      content: [LunaDialog.textContent(text: 'tdarr.RequeueDescription'.tr())],
      buttons: [
        LunaDialog.button(
          text: 'tdarr.Requeue'.tr(),
          onPressed: () {
            confirmed = true;
            Navigator.of(context).pop();
          },
        ),
      ],
    );
    if (!confirmed || !mounted) return;
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
    final searching = _searchController.text.trim().isNotEmpty;
    final results = _searchResults;
    final entries = results?.entries ?? const <TdarrStatusEntry>[];
    final loadedReports = widget.reports.take(100).toList();
    final visibleCount = results?.entries.length ?? loadedReports.length;
    final total = results?.totalCount ?? widget.totalCount;
    return LunaRefreshIndicator(
      context: context,
      onRefresh: () async => context.read<TdarrState>().refresh(),
      child: LunaListView(
        controller: widget.controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          LunaTextInputBar(
            controller: _searchController,
            onChanged: _search,
            labelText: widget.failed
                ? 'tdarr.SearchFailed'.tr()
                : 'tdarr.SearchCompleted'.tr(),
            scrollController: widget.controller,
          ),
          if (_searching) const LunaLoader(size: 14, useSafeArea: false),
          if (_searchError != null)
            LunaMessage.error(
              onTap: () => _search(_searchController.text),
              useSafeArea: false,
            )
          else if (searching && results != null) ...[
            LunaHeader(
              text: widget.failed
                  ? 'tdarr.Failed'.tr()
                  : 'tdarr.Completed'.tr(),
              subtitle: tdarrResultCount(loaded: visibleCount, total: total),
            ),
            if (entries.isEmpty)
              LunaMessage.inList(text: 'tdarr.NoMatchingFiles'.tr())
            else
              ...entries.map((entry) => _searchTile(entry)),
          ] else ...[
            LunaHeader(
              text: widget.failed
                  ? 'tdarr.Failed'.tr()
                  : 'tdarr.Completed'.tr(),
              subtitle: tdarrResultCount(
                loaded: loadedReports.length,
                total: total,
              ),
            ),
            if (loadedReports.isEmpty)
              LunaMessage.inList(
                text: widget.failed
                    ? 'tdarr.NoFailedTranscodes'.tr()
                    : 'tdarr.NoCompletedTranscodes'.tr(),
              )
            else
              ...loadedReports.map(_reportTile),
          ],
        ],
      ),
    );
  }

  Widget _searchTile(TdarrStatusEntry entry) => LunaBlock(
    title: entry.filename,
    leading: _statusIcon,
    body: [
      TextSpan(text: entry.status),
      TextSpan(
        text: entry.timestamp == null
            ? tdarrUnavailable
            : entry.timestamp!.asDateTime(),
      ),
    ],
  );

  Widget _reportTile(TdarrJobReport report) => LunaBlock(
    title: report.filename,
    leading: _statusIcon,
    body: [
      TextSpan(
        text: report.status,
        style: TextStyle(
          color: report.failed ? LunaColours.red : LunaColours.accent,
          fontWeight: LunaUI.FONT_WEIGHT_BOLD,
        ),
      ),
      TextSpan(
        text: report.timestamp.year == 1970
            ? tdarrUnavailable
            : report.timestamp.asDateTime(),
      ),
    ],
    trailing: report.failed && report.fileId.isNotEmpty
        ? (_isRequeuing(report.fileId)
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: LunaLoader(size: 16, useSafeArea: false),
                )
              : Tooltip(
                  message: 'tdarr.Requeue'.tr(),
                  child: LunaIconButton(
                    icon: Icons.replay_rounded,
                    onPressed: () => _requeue(report),
                  ),
                ))
        : report.jobFileId.isEmpty
        ? null
        : const LunaIconButton.arrow(),
    onTap: report.jobFileId.isEmpty
        ? null
        : () => TdarrRoutes.REPORT.go(extra: report),
  );

  Icon get _statusIcon => Icon(
    widget.failed ? Icons.error_rounded : Icons.check_circle_rounded,
    color: widget.failed ? LunaColours.red : LunaColours.accent,
  );

  bool _isRequeuing(String fileId) {
    try {
      return context.watch<TdarrState>().isRequeuing(fileId);
    } catch (_) {
      return false;
    }
  }
}
