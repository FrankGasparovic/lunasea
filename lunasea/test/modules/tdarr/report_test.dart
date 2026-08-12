import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunasea/modules/tdarr.dart';

void main() {
  test('splits Tdarr step entries and identifies the failed section', () {
    final sections = TdarrReportSection.parse('''
[Step S01] Server relay initialising job

1s

Node[node-a]:Worker[blue]:[Step W03] Running plugin

2s

Node[node-a]:Worker[blue]:[Step W09] [-error-] Job end
''', failedReport: true);

    expect(sections, hasLength(3));
    expect(sections[1].step, 'W03');
    expect(sections[1].source, 'Node[node-a]:Worker[blue]');
    expect(sections[1].duration, '2s');
    expect(sections[1].failed, isFalse);
    expect(sections[2].failed, isTrue);

    final successfulSections = TdarrReportSection.parse(
      '[Step W09] [-error-] Historical error text',
    );
    expect(successfulSections.single.failed, isFalse);
  });

  testWidgets(
    'long reports remain selectable with a single wrapped scroll view',
    (tester) async {
      final report = List.generate(
        400,
        (index) => index == 200
            ? 'ERROR: rejected by plugin'
            : 'line $index with a long diagnostic value',
      ).join('\n');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TdarrReportText(text: report)),
        ),
      );

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.textContaining('ERROR: rejected by plugin'), findsOneWidget);
      expect(find.text('400 lines'), findsOneWidget);
    },
  );

  testWidgets('step reports are rendered as expandable status sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TdarrReportText(
            text:
                '[Step W01] Received file\\n1s\\n[Step W09] [-error-] Job end',
            failedReport: true,
          ),
        ),
      ),
    );

    expect(find.byType(ExpansionTile), findsNWidgets(2));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
  });
}
