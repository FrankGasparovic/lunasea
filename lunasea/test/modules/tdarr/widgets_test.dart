import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tdarr.dart';

void main() {
  test('normalizes Tdarr progress from fractional and percentage values', () {
    expect(normalizeTdarrProgress(null), isNull);
    expect(normalizeTdarrProgress(0.25), 0.25);
    expect(normalizeTdarrProgress(25), 0.25);
    expect(normalizeTdarrProgress(-10), 0.0);
    expect(normalizeTdarrProgress(150), 1.0);
  });

  testWidgets('metric cards render at compact and wide widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TdarrMetricGrid(
            queued: 1,
            running: 2,
            successful: 3,
            failed: 4,
          ),
        ),
      ),
    );
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(900, 800));
    await tester.pump();
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('metric cards invoke their destination callbacks', (
    tester,
  ) async {
    TdarrMetric? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TdarrMetricGrid(
            queued: 1,
            running: 2,
            successful: 3,
            failed: 4,
            onTap: (metric) => tapped = metric,
          ),
        ),
      ),
    );

    await tester.tap(find.text('1'));
    expect(tapped, TdarrMetric.queued);
    await tester.tap(find.text('2'));
    expect(tapped, TdarrMetric.running);
    await tester.tap(find.text('3'));
    expect(tapped, TdarrMetric.successful);
    await tester.tap(find.text('4'));
    expect(tapped, TdarrMetric.failed);
  });

  testWidgets('transcode tiles label the worker status as a step', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TdarrTranscodeTile(
            item: TdarrTranscode(
              id: 'worker-1',
              nodeId: 'node-a',
              nodeName: 'Node A',
              filename: 'Episode.mkv',
              path: '/media/tv/Episode.mkv',
              workerType: 'transcodegpu',
              status: 'Movies 3 - Externalize Text Subtitles',
              eta: '0:00:20',
              plugin: 'Externalize Text Subtitles',
              percentage: 42,
              fps: 100,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains(
              'tdarr.Step: Movies 3 - Externalize Text Subtitles',
            ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('failed report sections start expanded', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TdarrReportText(
            text: '[Step W01] Received file\n1s\n[Step W09] [-error-] Job end',
            failedReport: true,
          ),
        ),
      ),
    );

    final tiles = tester.widgetList<ExpansionTile>(find.byType(ExpansionTile));
    expect(tiles.map((tile) => tile.initiallyExpanded), [false, true]);
  });

  testWidgets('node status says active when the pause switch is off', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TdarrNodeCard(
            node: const TdarrNode(
              id: 'node-a',
              name: 'Node A',
              online: true,
              cpuLimit: 1,
              gpuLimit: 3,
              transcodes: [],
            ),
            paused: false,
            pauseBusy: false,
            cpuLimit: 1,
            gpuLimit: 3,
            isWorkerBusy: (_) => false,
          ),
        ),
      ),
    );

    expect(find.text('tdarr.Active'), findsOneWidget);
    expect(find.text('tdarr.Paused'), findsNothing);
    expect(tester.widget<LunaSwitch>(find.byType(LunaSwitch)).value, isTrue);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('tdarr.GPUTranscode: 3'),
      ),
      findsOneWidget,
    );
  });
}
