import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/api/tdarr/tdarr.dart';

void main() {
  group('normalizeTdarrBaseUrl', () {
    test('preserves a reverse proxy path and removes trailing slashes', () {
      expect(
        normalizeTdarrBaseUrl('https://example.test/tdarr/'),
        'https://example.test/tdarr/api/v2/',
      );
    });

    test('does not duplicate an existing API suffix', () {
      expect(
        normalizeTdarrBaseUrl('https://example.test/tdarr/api/v2/'),
        'https://example.test/tdarr/api/v2/',
      );
    });
  });

  test('attaches the API key and worker payload to requests', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = TdarrAPI(
      host: 'https://example.test/tdarr/',
      apiKey: 'secret',
      headers: const {'X-Proxy': 'yes'},
      client: dio,
    );

    await api.alterWorkerLimit(
      nodeId: 'node-a',
      workerType: 'transcodegpu',
      increase: false,
    );

    final request = adapter.requests.single;
    expect(
      request.uri.toString(),
      'https://example.test/tdarr/api/v2/alter-worker-limit',
    );
    expect(request.headers['X-API-Key'], 'secret');
    expect(request.headers['X-Proxy'], 'yes');
    expect(request.data, {
      'data': {
        'nodeID': 'node-a',
        'process': 'decrease',
        'workerType': 'transcodegpu',
      },
    });
  });

  test('requeues a failed file with Tdarr\'s bulk update payload', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = TdarrAPI(
      host: 'https://example.test/tdarr/',
      apiKey: 'secret',
      client: dio,
    );

    await api.requeue(
      TdarrJobReport(
        fileId: 'file-1',
        footprintId: 'footprint-1',
        jobId: 'job-1',
        jobFileId: 'report.txt',
        filename: 'Failed movie',
        status: 'Transcode error',
        timestamp: DateTime(2025),
        failed: true,
      ),
    );

    final request = adapter.requests.single;
    expect(
      request.uri.toString(),
      'https://example.test/tdarr/api/v2/bulk-update-files',
    );
    expect(request.data, {
      'data': {
        'fileIds': ['file-1'],
        'updatedObj': {'TranscodeDecisionMaker': 'Queued'},
      },
    });
  });

  test('updates a node pause state', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = TdarrAPI(
      host: 'https://example.test/tdarr/',
      apiKey: 'secret',
      client: dio,
    );

    await api.setNodePaused(nodeId: 'node-a', paused: true);

    final request = adapter.requests.single;
    expect(request.uri.path, '/tdarr/api/v2/update-node');
    expect(request.data, {
      'data': {
        'nodeID': 'node-a',
        'nodeUpdates': {'nodePaused': true},
      },
    });
  });

  test('sets and clears Tdarr queue priority', () async {
    final adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = TdarrAPI(
      host: 'https://example.test/tdarr/',
      apiKey: 'secret',
      client: dio,
    );

    await api.setQueueBumped(fileId: 'file-a', bumped: false);

    final request = adapter.requests.single;
    expect(request.uri.path, '/tdarr/api/v2/bulk-update-files');
    expect(request.data, {
      'data': {
        'fileIds': ['file-a'],
        'updatedObj': {'bumped': 0},
      },
    });
  });

  test('defensively parses workers and classifies reports', () {
    final dashboard = TdarrDashboardData.fromResponses(
      {'status': 'good', 'version': '2.00.20', 'uptime': 61},
      {
        'nodes': {
          'node-a': {
            'nodeName': 'Garage',
            'connected': true,
            'nodePaused': true,
            'workerLimits': {'transcodecpu': 2, 'transcodegpu': 1},
            'workers': {
              'worker-1': {
                'workerType': 'transcodecpu',
                'file': '/media/Movie.mkv',
                'percentage': '42%',
                'fps': 70.5,
                'ETA': '0:04:12',
                'status': 'Transcoding',
              },
              'broken': null,
            },
          },
        },
      },
      {
        'jobReports': [
          {
            'filename': 'abc()2.86.01()transcode()job-1()1700000000000.txt',
            'lastModifiedMs': 1700000000000,
          },
          {
            'filename': 'def()2.86.01()transcode()job-2()1700000001000.txt',
            'lastModifiedMs': 1700000001000,
          },
        ],
      },
      {'totalCount': 4, 'array': const []},
      {
        'totalCount': 1,
        'array': [
          {
            '_id': 'file-good',
            'footprintId': 'abc',
            'fileNameWithoutExtension': 'Good',
            'TranscodeDecisionMaker': 'Transcode success',
            'lastTranscodeDate': 1700000000000,
          },
        ],
      },
      {
        'totalCount': 1,
        'array': [
          {
            '_id': 'file-bad',
            'footprintId': 'def',
            'fileNameWithoutExtension': 'Bad',
            'TranscodeDecisionMaker': 'Transcode error',
            'lastTranscodeDate': 1700000001000,
          },
        ],
      },
    );

    expect(dashboard.nodes.single.cpuLimit, 2);
    expect(dashboard.nodes.single.isPaused, isTrue);
    expect(dashboard.transcodes.single.filename, 'Movie.mkv');
    expect(dashboard.transcodes.single.percentage, 42);
    expect(dashboard.queued, 4);
    expect(dashboard.successful, 1);
    expect(dashboard.failed, 1);
    expect(dashboard.completedReports.single.filename, 'Good');
    expect(dashboard.failedReports.single.filename, 'Bad');
    expect(dashboard.failedReports.single.fileId, 'file-bad');
  });

  test('uses missing-field fallbacks and identifies diagnostic lines', () {
    final nodes = TdarrNode.parseList({
      'node-a': {'workers': {}},
    });

    expect(nodes.single.name, 'node-a');
    expect(nodes.single.cpuLimit, 0);
    expect(isTdarrErrorLine('Plugin rejected the file'), isTrue);
    expect(isTdarrErrorLine('Transcode complete'), isFalse);
    expect(
      normalizeTdarrReportText(r'first\nsecond\tvalue'),
      'first\nsecond  value',
    );
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
