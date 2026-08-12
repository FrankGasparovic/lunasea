import 'package:lunasea/vendor.dart';

const tdarrUnavailable = '—';

bool isTdarrErrorLine(String line) =>
    RegExp(r'error|fail|reject', caseSensitive: false).hasMatch(line);

/// Converts an escaped API response into the line-oriented report Tdarr wrote.
/// Some proxies return the report body as a JSON string, leaving its newline
/// and tab escapes visible to the user.
String normalizeTdarrReportText(String text) {
  var result = text;
  final trimmed = text.trim();
  if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is String) result = decoded;
    } catch (_) {
      // This is a normal plain-text report rather than a JSON string.
    }
  }
  return result
      .replaceAll(r'\r\n', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '  ')
      .replaceAll('\r\n', '\n');
}

String normalizeTdarrBaseUrl(String host) {
  var value = host.trim();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  value = value.replaceFirst(RegExp(r'/api/v2$', caseSensitive: false), '');
  return '$value/api/v2/';
}

class TdarrAPIException implements Exception {
  final String message;
  final int? statusCode;

  const TdarrAPIException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class TdarrAPI {
  final Dio dio;
  final String baseUrl;

  TdarrAPI({
    required String host,
    required String apiKey,
    Map<String, dynamic> headers = const {},
    Dio? client,
  }) : baseUrl = normalizeTdarrBaseUrl(host),
       dio = client ?? Dio() {
    dio.options.headers.addAll(<String, dynamic>{
      ...headers,
      'X-API-Key': apiKey,
      Headers.acceptHeader: Headers.jsonContentType,
    });
    dio.options.contentType = Headers.jsonContentType;
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 30);
    dio.options.followRedirects = true;
    dio.options.maxRedirects = 5;
  }

  Future<dynamic> _get(String path) async {
    try {
      final response = await dio.get<dynamic>('$baseUrl$path');
      return _validate(response);
    } on DioException catch (error) {
      throw _friendlyError(error);
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    try {
      final response = await dio.post<dynamic>(
        '$baseUrl$path',
        data: <String, dynamic>{'data': data},
      );
      return _validate(response);
    } on DioException catch (error) {
      throw _friendlyError(error);
    }
  }

  dynamic _validate(Response<dynamic> response) {
    final data = response.data;
    final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';
    if (contentType.toLowerCase().contains('text/html') ||
        data is String &&
            data.trimLeft().toLowerCase().startsWith('<!doctype html')) {
      throw const TdarrAPIException(
        'Tdarr returned an HTML page. Check the URL and reverse-proxy routing.',
      );
    }
    return data;
  }

  TdarrAPIException _friendlyError(DioException error) {
    final code = error.response?.statusCode;
    if (code == 401 || code == 403) {
      return TdarrAPIException('Tdarr rejected the API key.', statusCode: code);
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const TdarrAPIException(
        'Could not connect to Tdarr. Check the URL and network connection.',
      );
    }
    return TdarrAPIException(
      'Tdarr request failed${code == null ? '' : ' (HTTP $code)'}.',
      statusCode: code,
    );
  }

  Future<TdarrServerStatus> getStatus() async {
    final response = await _get('status');
    if (response is! Map) {
      throw const TdarrAPIException(
        'Tdarr returned an unexpected response. Check the URL and proxy configuration.',
      );
    }
    return TdarrServerStatus.fromJson(_map(response));
  }

  Future<List<TdarrNode>> getNodes() async =>
      TdarrNode.parseList(await _get('get-nodes'));

  Future<TdarrDashboardData> getDashboard() async {
    final values = await Future.wait<dynamic>([
      _get('status'),
      _get('get-nodes'),
      _post('search-job-reports', const <String, dynamic>{'searchTerms': ''}),
      _post('client/status-tables', _statusTableRequest('table1')),
      _post('client/status-tables', _statusTableRequest('table2')),
      _post('client/status-tables', _statusTableRequest('table3')),
    ]);
    return TdarrDashboardData.fromResponses(
      values[0],
      values[1],
      values[2],
      values[3],
      values[4],
      values[5],
    );
  }

  Map<String, dynamic> _statusTableRequest(String table) => <String, dynamic>{
    'start': 0,
    'pageSize': 100,
    'filters': const <dynamic>[],
    'sorts': const <dynamic>[],
    'opts': <String, dynamic>{'table': table},
  };

  Future<TdarrStatusTable> getStatusTable(
    String table, {
    String search = '',
    int start = 0,
  }) async => TdarrStatusTable.fromJson(
    await _post('client/status-tables', <String, dynamic>{
      'start': start,
      'pageSize': 100,
      'filters': search.trim().isEmpty
          ? const <dynamic>[]
          : <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'fileNameWithoutExtension',
                'value': search.trim(),
              },
            ],
      'sorts': const <dynamic>[],
      'opts': <String, dynamic>{'table': table},
    }),
  );

  Future<void> alterWorkerLimit({
    required String nodeId,
    required String workerType,
    required bool increase,
  }) async {
    if (workerType != 'transcodecpu' && workerType != 'transcodegpu') {
      throw ArgumentError.value(workerType, 'workerType');
    }
    await _post('alter-worker-limit', <String, dynamic>{
      'nodeID': nodeId,
      'process': increase ? 'increase' : 'decrease',
      'workerType': workerType,
    });
  }

  Future<void> setNodePaused({required String nodeId, required bool paused}) =>
      _post('update-node', <String, dynamic>{
        'nodeID': nodeId,
        'nodeUpdates': <String, dynamic>{'nodePaused': paused},
      });

  Future<String> readReport(TdarrJobReport report) async {
    final result = await _post('read-job-file', <String, dynamic>{
      'footprintId': report.footprintId,
      'jobId': report.jobId,
      'jobFileId': report.jobFileId,
    });
    if (result is String) return normalizeTdarrReportText(result);
    if (result is Map) {
      for (final key in const ['text', 'data', 'content', 'report']) {
        if (result[key] is String) {
          return normalizeTdarrReportText(result[key] as String);
        }
      }
    }
    return const JsonEncoder.withIndent('  ').convert(result);
  }

  Future<void> requeue(TdarrJobReport report) async {
    if (report.fileId.isEmpty) {
      throw const TdarrAPIException(
        'Tdarr did not provide the file identifier needed to requeue this entry.',
      );
    }
    await _post('bulk-update-files', <String, dynamic>{
      'fileIds': [report.fileId],
      'updatedObj': <String, dynamic>{'TranscodeDecisionMaker': 'Queued'},
    });
  }

  Future<void> setQueueBumped({required String fileId, required bool bumped}) =>
      _post('bulk-update-files', <String, dynamic>{
        'fileIds': [fileId],
        'updatedObj': <String, dynamic>{
          'bumped': bumped ? DateTime.now().millisecondsSinceEpoch : 0,
        },
      });
}

class TdarrServerStatus {
  final String status;
  final String version;
  final int? uptimeSeconds;

  const TdarrServerStatus({
    required this.status,
    required this.version,
    required this.uptimeSeconds,
  });

  factory TdarrServerStatus.fromJson(Map<String, dynamic> json) {
    return TdarrServerStatus(
      status: _string(json, const ['status']) ?? tdarrUnavailable,
      version:
          _string(json, const ['version', 'serverVersion']) ?? tdarrUnavailable,
      uptimeSeconds: _integer(json, const ['uptime', 'uptimeSeconds']),
    );
  }
}

class TdarrDashboardData {
  final TdarrServerStatus status;
  final List<TdarrNode> nodes;
  final List<TdarrTranscode> transcodes;
  final List<TdarrJobReport> completedReports;
  final List<TdarrJobReport> failedReports;
  final int queued;
  final int successful;
  final int failed;

  const TdarrDashboardData({
    required this.status,
    required this.nodes,
    required this.transcodes,
    required this.completedReports,
    required this.failedReports,
    required this.queued,
    required this.successful,
    required this.failed,
  });

  factory TdarrDashboardData.fromResponses(
    dynamic statusResponse,
    dynamic nodesResponse,
    dynamic reportsResponse,
    dynamic queueResponse,
    dynamic completedResponse,
    dynamic failedResponse,
  ) {
    final nodes = TdarrNode.parseList(nodesResponse);
    final reports = TdarrJobReport.parseList(reportsResponse)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final transcodes = nodes.expand((node) => node.transcodes).toList();
    final reportsByFootprint = <String, List<TdarrJobReport>>{};
    for (final report in reports) {
      reportsByFootprint.putIfAbsent(report.footprintId, () => []).add(report);
    }
    final queue = TdarrStatusTable.fromJson(queueResponse);
    final completed = TdarrStatusTable.fromJson(completedResponse);
    final failed = TdarrStatusTable.fromJson(failedResponse);
    return TdarrDashboardData(
      status: TdarrServerStatus.fromJson(_map(statusResponse)),
      nodes: nodes,
      transcodes: transcodes,
      completedReports: completed.reports(reportsByFootprint, failed: false),
      failedReports: failed.reports(reportsByFootprint, failed: true),
      queued: queue.totalCount,
      successful: completed.totalCount,
      failed: failed.totalCount,
    );
  }
}

class TdarrStatusTable {
  final int totalCount;
  final List<Map<String, dynamic>> rows;

  const TdarrStatusTable({required this.totalCount, required this.rows});

  factory TdarrStatusTable.fromJson(dynamic value) {
    final json = _map(value);
    final rows = (json['array'] is List ? json['array'] as List : const [])
        .whereType<Map>()
        .map(_map)
        .toList();
    return TdarrStatusTable(
      totalCount: _integer(json, const ['totalCount']) ?? rows.length,
      rows: rows,
    );
  }

  List<TdarrStatusEntry> get entries => rows
      .map(TdarrStatusEntry.fromJson)
      .where((entry) => entry.fileId.isNotEmpty)
      .toList();

  List<TdarrJobReport> reports(
    Map<String, List<TdarrJobReport>> reportsByFootprint, {
    required bool failed,
  }) {
    final result = rows.map((row) {
      final footprintId = _string(row, const ['footprintId']) ?? '';
      final matched = reportsByFootprint[footprintId];
      final metadata = matched?.isNotEmpty == true ? matched!.first : null;
      return TdarrJobReport(
        fileId: _string(row, const ['_id', 'fileId', 'id']) ?? '',
        footprintId: footprintId,
        jobId: metadata?.jobId ?? '',
        jobFileId: metadata?.jobFileId ?? '',
        filename:
            _string(row, const ['fileNameWithoutExtension', 'file', '_id']) ??
            metadata?.filename ??
            tdarrUnavailable,
        status:
            _string(row, const ['TranscodeDecisionMaker', 'HealthCheck']) ??
            (failed ? 'Failed' : 'Completed'),
        timestamp:
            _date(row) ??
            metadata?.timestamp ??
            DateTime.fromMillisecondsSinceEpoch(0),
        failed: failed,
      );
    }).toList();
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }
}

class TdarrStatusEntry {
  final String fileId;
  final String filename;
  final String path;
  final String status;
  final DateTime? timestamp;
  final bool bumped;

  const TdarrStatusEntry({
    required this.fileId,
    required this.filename,
    required this.path,
    required this.status,
    required this.timestamp,
    required this.bumped,
  });

  factory TdarrStatusEntry.fromJson(Map<String, dynamic> json) {
    final path = _string(json, const ['file', '_id']) ?? tdarrUnavailable;
    return TdarrStatusEntry(
      fileId: _string(json, const ['_id', 'fileId', 'id']) ?? '',
      filename:
          _string(json, const ['fileNameWithoutExtension', 'filename']) ??
          _basename(path),
      path: path,
      status:
          _string(json, const ['TranscodeDecisionMaker', 'HealthCheck']) ??
          tdarrUnavailable,
      timestamp: _date(json),
      bumped: (_num(json, const ['bumped']) ?? 0) > 0,
    );
  }
}

class TdarrNode {
  final String id;
  final String name;
  final bool online;
  final bool? paused;
  final int cpuLimit;
  final int gpuLimit;
  final List<TdarrTranscode> transcodes;

  const TdarrNode({
    required this.id,
    required this.name,
    required this.online,
    this.paused,
    required this.cpuLimit,
    required this.gpuLimit,
    required this.transcodes,
  });

  bool get isPaused => paused ?? false;

  static List<TdarrNode> parseList(dynamic response) {
    final root = response is Map && response['data'] != null
        ? response['data']
        : response;
    final entries = <MapEntry<String, dynamic>>[];
    if (root is List) {
      for (var i = 0; i < root.length; i++) {
        entries.add(MapEntry('$i', root[i]));
      }
    } else if (root is Map) {
      final candidate = root['nodes'] ?? root['data'] ?? root;
      if (candidate is List) {
        for (var i = 0; i < candidate.length; i++) {
          entries.add(MapEntry('$i', candidate[i]));
        }
      } else if (candidate is Map) {
        entries.addAll(
          candidate.entries.map(
            (entry) => MapEntry('${entry.key}', entry.value),
          ),
        );
      }
    }
    return entries
        .map((entry) {
          final json = _map(entry.value);
          final id =
              _string(json, const ['nodeID', 'nodeId', 'id', '_id']) ??
              entry.key;
          final workerLimits = _map(json['workerLimits'] ?? json['limits']);
          final workers =
              json['workers'] ?? json['workerInfo'] ?? json['activeWorkers'];
          final name = _string(json, const ['nodeName', 'name']) ?? id;
          return TdarrNode(
            id: id,
            name: name,
            online:
                _boolean(json, const ['connected', 'online', 'isOnline']) ??
                true,
            paused: _boolean(json, const ['nodePaused', 'paused', 'isPaused']),
            cpuLimit:
                _integer(workerLimits, const [
                  'transcodecpu',
                  'transcodeCPU',
                ]) ??
                _integer(json, const ['transcodecpu', 'transcodeCpuWorkers']) ??
                0,
            gpuLimit:
                _integer(workerLimits, const [
                  'transcodegpu',
                  'transcodeGPU',
                ]) ??
                _integer(json, const ['transcodegpu', 'transcodeGpuWorkers']) ??
                0,
            transcodes: TdarrTranscode.parseWorkers(
              workers,
              nodeId: id,
              nodeName: name,
            ),
          );
        })
        .where((node) => node.id.isNotEmpty)
        .toList();
  }
}

class TdarrTranscode {
  final String id;
  final String nodeId;
  final String? nodeName;
  final String filename;
  final String path;
  final String workerType;
  final String status;
  final String eta;
  final String plugin;
  final double? percentage;
  final double? fps;

  const TdarrTranscode({
    required this.id,
    required this.nodeId,
    this.nodeName,
    required this.filename,
    required this.path,
    required this.workerType,
    required this.status,
    required this.eta,
    required this.plugin,
    required this.percentage,
    required this.fps,
  });

  static List<TdarrTranscode> parseWorkers(
    dynamic value, {
    required String nodeId,
    required String nodeName,
  }) {
    final records = <MapEntry<String, dynamic>>[];
    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        records.add(MapEntry('$i', value[i]));
      }
    } else if (value is Map) {
      records.addAll(
        value.entries.map((entry) => MapEntry('${entry.key}', entry.value)),
      );
    }
    return records
        .map((entry) {
          final json = _map(entry.value);
          final fileValue = json['file'] ?? json['item'] ?? json['currentFile'];
          final file = _map(fileValue);
          final path =
              _string(json, const ['filePath', 'sourceFile', 'path']) ??
              (fileValue is String ? fileValue : null) ??
              _string(file, const ['file', 'path', '_id']) ??
              tdarrUnavailable;
          return TdarrTranscode(
            id:
                _string(json, const ['workerID', 'workerId', 'id']) ??
                entry.key,
            nodeId: nodeId,
            nodeName: nodeName,
            filename:
                _string(json, const ['fileName', 'filename']) ??
                _string(file, const ['fileName', 'filename']) ??
                _basename(path),
            path: path,
            workerType:
                _string(json, const ['workerType', 'type']) ?? tdarrUnavailable,
            status:
                _string(json, const ['status', 'statusText', 'stage']) ??
                tdarrUnavailable,
            eta:
                _string(json, const ['ETA', 'eta', 'estimatedTimeRemaining']) ??
                tdarrUnavailable,
            plugin:
                _string(json, const [
                  'plugin',
                  'pluginName',
                  'currentPlugin',
                ]) ??
                _string(_map(json['lastPluginDetails']), const [
                  'plugin',
                  'pluginName',
                  'name',
                ]) ??
                tdarrUnavailable,
            percentage: _number(json, const [
              'percentage',
              'percent',
              'progress',
            ]),
            fps: _number(json, const ['fps', 'FPS']),
          );
        })
        .where((item) {
          final type = item.workerType.toLowerCase();
          return type.contains('transcode') || item.path != tdarrUnavailable;
        })
        .toList();
  }
}

class TdarrJobReport {
  final String fileId;
  final String footprintId;
  final String jobId;
  final String jobFileId;
  final String filename;
  final String status;
  final DateTime timestamp;
  final bool failed;

  const TdarrJobReport({
    required this.fileId,
    required this.footprintId,
    required this.jobId,
    required this.jobFileId,
    required this.filename,
    required this.status,
    required this.timestamp,
    required this.failed,
  });

  static List<TdarrJobReport> parseList(dynamic response) {
    dynamic value = response;
    if (value is Map) {
      value =
          value['data'] ??
          value['jobReports'] ??
          value['reports'] ??
          value['results'] ??
          value;
    }
    final records = value is List
        ? value
        : value is Map
        ? value.values.toList()
        : const [];
    return records
        .map<TdarrJobReport?>((raw) {
          final json = raw is String
              ? <String, dynamic>{'jobFileId': raw}
              : _map(raw);
          final jobFileId =
              _string(json, const [
                'jobFileId',
                'filename',
                'fileName',
                'id',
                '_id',
              ]) ??
              '';
          if (jobFileId.isEmpty) return null;
          final parts = jobFileId.split('()');
          final footprint =
              _string(json, const ['footprintId', 'footprintID']) ??
              (parts.isNotEmpty ? parts.first : '');
          final job =
              _string(json, const ['jobId', 'jobID']) ??
              (parts.length > 3 ? parts[3] : '');
          final status =
              _string(json, const ['status', 'result', 'verdict']) ??
              tdarrUnavailable;
          final combined = '$status ${json['error'] ?? ''} $jobFileId'
              .toLowerCase();
          final stamp =
              _date(json) ??
              (parts.length > 4
                  ? DateTime.fromMillisecondsSinceEpoch(
                      int.tryParse(parts[4].split('.').first) ?? 0,
                    )
                  : DateTime.fromMillisecondsSinceEpoch(0));
          return TdarrJobReport(
            fileId: _string(json, const ['fileId', 'id', '_id']) ?? '',
            footprintId: footprint,
            jobId: job,
            jobFileId: jobFileId,
            filename:
                _string(json, const [
                  'originalFileName',
                  'sourceFile',
                  'file',
                ]) ??
                _basename(footprint),
            status: status,
            timestamp: stamp,
            failed:
                combined.contains('fail') ||
                combined.contains('error') ||
                combined.contains('reject'),
          );
        })
        .whereType<TdarrJobReport>()
        .toList();
  }
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : <String, dynamic>{};

String? _string(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null && '$value'.trim().isNotEmpty) return '$value';
  }
  return null;
}

num? _num(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value;
    final parsed = num.tryParse('$value'.replaceAll('%', ''));
    if (parsed != null) return parsed;
  }
  return null;
}

int? _integer(Map<String, dynamic> json, List<String> keys) =>
    _num(json, keys)?.toInt();

double? _number(Map<String, dynamic> json, List<String> keys) =>
    _num(json, keys)?.toDouble();

bool? _boolean(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if ('$value'.toLowerCase() == 'true') return true;
    if ('$value'.toLowerCase() == 'false') return false;
  }
  return null;
}

DateTime? _date(Map<String, dynamic> json) {
  for (final key in const [
    'timestamp',
    'lastModifiedMs',
    'lastTranscodeDate',
    'createdAt',
    'start',
    'date',
    'time',
  ]) {
    final value = json[key];
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value < 100000000000 ? value.toInt() * 1000 : value.toInt(),
      );
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      final epoch = int.tryParse(value);
      if (epoch != null) return DateTime.fromMillisecondsSinceEpoch(epoch);
    }
  }
  return null;
}

String _basename(String path) {
  if (path == tdarrUnavailable) return path;
  final parts = path.replaceAll('\\', '/').split('/');
  return parts.lastWhere(
    (part) => part.isNotEmpty,
    orElse: () => tdarrUnavailable,
  );
}
