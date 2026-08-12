import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tdarr.dart';

class TdarrState extends LunaModuleState {
  TdarrAPI? _api;
  TdarrAPI? get api => _api;

  bool _enabled = false;
  bool get enabled => _enabled;

  Future<TdarrDashboardData>? _dashboard;
  Future<TdarrDashboardData>? get dashboard => _dashboard;

  final Set<String> _mutating = <String>{};
  final Map<String, int> _workerLimitOverrides = <String, int>{};
  final Map<String, bool> _nodePauseOverrides = <String, bool>{};
  bool isMutating(String nodeId, String workerType) =>
      _mutating.contains('$nodeId:$workerType');
  bool isRequeuing(String fileId) => _mutating.contains('requeue:$fileId');
  bool isUpdatingNode(String nodeId) => _mutating.contains('node:$nodeId');
  bool isUpdatingQueue(String fileId) => _mutating.contains('queue:$fileId');
  int workerLimit(String nodeId, String workerType, int serverValue) =>
      _workerLimitOverrides['$nodeId:$workerType'] ?? serverValue;
  bool nodePaused(TdarrNode node) =>
      _nodePauseOverrides[node.id] ?? node.isPaused;

  TdarrState() {
    reset();
  }

  @override
  void reset() {
    final profile = LunaProfile.current;
    _enabled =
        profile.tdarrEnabled &&
        LunaConnectionDetails.isReady(
          host: profile.tdarrHost,
          apiKey: profile.tdarrKey,
        );
    if (profile.tdarrEnabled != _enabled) {
      profile.tdarrEnabled = false;
      profile.save();
    }
    _api = _enabled
        ? TdarrAPI(
            host: profile.tdarrHost,
            apiKey: profile.tdarrKey,
            headers: Map<String, dynamic>.from(profile.tdarrHeaders),
          )
        : null;
    _dashboard = _api?.getDashboard();
    notifyListeners();
  }

  Future<void> refresh() async {
    final api = _api;
    if (api == null) return;
    _dashboard = api.getDashboard();
    notifyListeners();
    await _dashboard;
  }

  Future<void> alterWorkerLimit({
    required String nodeId,
    required String workerType,
    required bool increase,
    required int currentLimit,
  }) async {
    if (!increase && currentLimit <= 0) return;
    final mutation = '$nodeId:$workerType';
    if (_mutating.contains(mutation) || _api == null) return;
    _workerLimitOverrides[mutation] = currentLimit + (increase ? 1 : -1);
    _mutating.add(mutation);
    notifyListeners();
    try {
      await _api!.alterWorkerLimit(
        nodeId: nodeId,
        workerType: workerType,
        increase: increase,
      );
    } catch (_) {
      _workerLimitOverrides.remove(mutation);
      rethrow;
    } finally {
      _mutating.remove(mutation);
      notifyListeners();
      unawaited(_refreshAndClearWorkerOverride(mutation));
    }
  }

  Future<void> requeue(TdarrJobReport report) async {
    if (_api == null || report.fileId.isEmpty) return;
    final mutation = 'requeue:${report.fileId}';
    if (_mutating.contains(mutation)) return;
    _mutating.add(mutation);
    notifyListeners();
    try {
      await _api!.requeue(report);
    } finally {
      _mutating.remove(mutation);
      notifyListeners();
      unawaited(refresh().catchError((_) {}));
    }
  }

  Future<void> setNodePaused(TdarrNode node, bool paused) async {
    if (_api == null) return;
    final mutation = 'node:${node.id}';
    if (_mutating.contains(mutation)) return;
    _nodePauseOverrides[node.id] = paused;
    _mutating.add(mutation);
    notifyListeners();
    try {
      await _api!.setNodePaused(nodeId: node.id, paused: paused);
    } catch (_) {
      _nodePauseOverrides.remove(node.id);
      rethrow;
    } finally {
      _mutating.remove(mutation);
      notifyListeners();
      unawaited(_refreshAndClearNodePauseOverride(node.id));
    }
  }

  Future<void> setQueueBumped(TdarrStatusEntry entry, bool bumped) async {
    if (_api == null || entry.fileId.isEmpty) return;
    final mutation = 'queue:${entry.fileId}';
    if (_mutating.contains(mutation)) return;
    _mutating.add(mutation);
    notifyListeners();
    try {
      await _api!.setQueueBumped(fileId: entry.fileId, bumped: bumped);
    } finally {
      _mutating.remove(mutation);
      notifyListeners();
    }
  }

  Future<void> _refreshAndClearWorkerOverride(String mutation) async {
    try {
      await refresh();
    } catch (_) {
      return;
    }
    _workerLimitOverrides.remove(mutation);
    notifyListeners();
  }

  Future<void> _refreshAndClearNodePauseOverride(String nodeId) async {
    try {
      await refresh();
    } catch (_) {
      return;
    }
    _nodePauseOverrides.remove(nodeId);
    notifyListeners();
  }
}
