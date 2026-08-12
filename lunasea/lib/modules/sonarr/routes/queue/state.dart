import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';

class SonarrQueueState extends ChangeNotifier {
  SonarrQueueState(this._sonarr) {
    fetchQueue();
  }

  final SonarrState _sonarr;
  Timer? _timer;
  bool _disposed = false;

  void cancelTimer() => _timer?.cancel();
  void createTimer() {
    _timer = Timer.periodic(
      Duration(seconds: SonarrDatabase.QUEUE_REFRESH_RATE.read()),
      (_) => fetchQueue(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    cancelTimer();
    super.dispose();
  }

  late Future<SonarrQueuePage> _queue;
  Future<SonarrQueuePage> get queue => _queue;
  set queue(Future<SonarrQueuePage> queue) {
    _queue = queue;
    notifyListeners();
  }

  Future<void> fetchQueue({bool hardCheck = false}) async {
    cancelTimer();
    final api = _sonarr.api;
    if (_sonarr.enabled && api != null) {
      if (hardCheck) {
        // "Hard" check by telling Sonarr to refresh the monitored downloads
        // Give it 500 ms to internally check and then continue to fetch queue
        await api.command.refreshMonitoredDownloads().then(
          (_) => Future.delayed(const Duration(milliseconds: 500), () {}),
        );
      }
      if (_disposed || !_sonarr.enabled || _sonarr.api != api) return;
      _queue = api.queue.get(
        includeEpisode: true,
        includeSeries: true,
        pageSize: SonarrDatabase.QUEUE_PAGE_SIZE.read(),
      );
      createTimer();
    }
    if (!_disposed) notifyListeners();
  }
}
