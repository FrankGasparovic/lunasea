import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/system/cache/memory/memory_cache.dart';

class SonarrSeasonDetailsState extends ChangeNotifier {
  final SonarrState _sonarr;
  final int seriesId;
  final int? seasonNumber;
  int _currentQueueItems = 0;
  int? currentEpisodeId;
  bool _disposed = false;

  SonarrSeasonDetailsState({
    required SonarrState sonarr,
    required this.seriesId,
    required this.seasonNumber,
  }) : _sonarr = sonarr {
    fetchState(queueHardCheck: false);
  }

  Future<void> fetchState({
    bool shouldFetchEpisodes = true,
    bool shouldFetchFiles = true,
    bool shouldFetchHistory = true,
    bool shouldFetchQueue = true,
    bool queueHardCheck = true,
    bool shouldFetchMostRecentEpisodeHistory = true,
  }) async {
    if (_disposed) return;
    if (shouldFetchEpisodes) fetchEpisodes();
    if (shouldFetchFiles) fetchFiles();
    if (shouldFetchHistory) fetchHistory();
    if (shouldFetchQueue) fetchQueue(hardCheck: queueHardCheck);
    if (shouldFetchMostRecentEpisodeHistory)
      fetchEpisodeHistory(currentEpisodeId);
  }

  @override
  void dispose() {
    _disposed = true;
    _queueTimer?.cancel();
    super.dispose();
  }

  LunaLoadingState _episodeSearchState = LunaLoadingState.INACTIVE;
  LunaLoadingState get episodeSearchState => _episodeSearchState;
  set episodeSearchState(LunaLoadingState state) {
    _episodeSearchState = state;
    notifyListeners();
  }

  final _episodeHistoryCache = LunaMemoryCache<Future<SonarrHistoryPage>>(
    maxEntries: 10,
    module: LunaModule.SONARR,
    id: 'episode_history_cache',
  );

  Future<void> fetchEpisodeHistory(int? episodeId) async {
    if (_sonarr.enabled && _sonarr.api != null) {
      _episodeHistoryCache.put(
        episodeId.toString(),
        _sonarr.api!.history.get(pageSize: 1000, episodeId: episodeId),
      );
    }
    notifyListeners();
  }

  Future<SonarrHistoryPage?> getEpisodeHistory(int episodeId) async {
    String id = episodeId.toString();
    return await _episodeHistoryCache.get(id);
  }

  Future<Map<int, SonarrEpisode>>? _episodes;
  Future<Map<int, SonarrEpisode>>? get episodes => _episodes;
  Future<void> fetchEpisodes() async {
    if (_sonarr.enabled && _sonarr.api != null) {
      _episodes = _sonarr.api!.episode
          .getMulti(seriesId: seriesId, seasonNumber: seasonNumber)
          .then((episodes) {
            return {for (SonarrEpisode e in episodes) e.id!: e};
          });
    }
    notifyListeners();
  }

  Future<void> setSingleEpisode(SonarrEpisode episode) async {
    (await _episodes)![episode.id!] = episode;
    notifyListeners();
  }

  Future<List<SonarrHistoryRecord>>? _history;
  Future<List<SonarrHistoryRecord>>? get history => _history;
  Future<void> fetchHistory() async {
    if (this.seasonNumber == null) return;
    if (_sonarr.enabled && _sonarr.api != null) {
      _history = _sonarr.api!.history.getBySeries(
        seriesId: seriesId,
        seasonNumber: seasonNumber,
      );
    }
    notifyListeners();
  }

  Future<Map<int, SonarrEpisodeFile>>? _files;
  Future<Map<int, SonarrEpisodeFile>>? get files => _files;
  Future<void> fetchFiles() async {
    if (_sonarr.enabled && _sonarr.api != null) {
      _files = _sonarr.api!.episodeFile.getSeries(seriesId: seriesId).then((
        files,
      ) {
        return {for (SonarrEpisodeFile f in files) f.id!: f};
      });
    }
    notifyListeners();
  }

  Timer? _queueTimer;
  void cancelQueueTimer() => _queueTimer?.cancel();
  void createQueueTimer() {
    _queueTimer = Timer.periodic(
      Duration(seconds: SonarrDatabase.QUEUE_REFRESH_RATE.read()),
      (_) => fetchQueue(),
    );
  }

  late Future<List<SonarrQueueRecord>> _queue;
  Future<List<SonarrQueueRecord>> get queue => _queue;
  set queue(Future<List<SonarrQueueRecord>> queue) {
    _queue = queue;
    notifyListeners();
  }

  Future<void> fetchQueue({bool hardCheck = false}) async {
    cancelQueueTimer();
    final api = _sonarr.api;
    if (_sonarr.enabled && api != null) {
      // "Hard" check by telling Sonarr to refresh the monitored downloads
      // Give it 500 ms to internally check and then continue to fetch queue
      if (hardCheck) {
        await api.command.refreshMonitoredDownloads().then(
          (_) => Future.delayed(const Duration(milliseconds: 500), () {}),
        );
      }
      if (_disposed || !_sonarr.enabled || _sonarr.api != api) return;
      _queue = api.queue
          .getDetails(seriesId: seriesId, includeEpisode: true)
          .then((queue) {
            if (_disposed) return queue;
            if (_currentQueueItems != queue.length) {
              fetchState(shouldFetchQueue: false);
            }
            _currentQueueItems = queue.length;
            return queue;
          });
      createQueueTimer();
    }
    if (!_disposed) notifyListeners();
  }

  final Set<int> selectedEpisodes = {};

  void toggleSelectedEpisode(SonarrEpisode episode) {
    final id = episode.id!;
    if (selectedEpisodes.contains(id)) {
      selectedEpisodes.remove(id);
    } else {
      selectedEpisodes.add(id);
    }

    notifyListeners();
  }

  void clearSelectedEpisodes() {
    selectedEpisodes.clear();
    notifyListeners();
  }

  Future<void> toggleSeasonEpisodes(int seasonNumber) async {
    final eps = (await episodes)!
        .filter((ep) => ep.value.seasonNumber == seasonNumber)
        .map((ep) => ep.value.id!)
        .toList();
    final allSelected = eps.every(selectedEpisodes.contains);

    if (allSelected) {
      selectedEpisodes.removeAll(eps);
    } else {
      selectedEpisodes.addAll(eps);
    }

    notifyListeners();
  }
}
