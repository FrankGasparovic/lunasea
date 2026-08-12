import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tdarr.dart';

class TdarrReportRoute extends StatefulWidget {
  final TdarrJobReport report;

  const TdarrReportRoute({super.key, required this.report});

  @override
  State<TdarrReportRoute> createState() => _TdarrReportRouteState();
}

class _TdarrReportRouteState extends State<TdarrReportRoute> {
  late Future<String> _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _report = context.read<TdarrState>().api!.readReport(widget.report);
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return LunaScaffold(
      scaffoldKey: GlobalKey<ScaffoldState>(),
      appBar: LunaAppBar(title: widget.report.filename),
      body: FutureBuilder<String>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return LunaMessage.error(onTap: _retry);
          }
          return TdarrReportText(
            text: snapshot.data ?? '',
            failedReport: widget.report.failed,
          );
        },
      ),
    );
  }
}

class TdarrReportText extends StatelessWidget {
  final String text;
  final bool failedReport;

  const TdarrReportText({
    super.key,
    required this.text,
    this.failedReport = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeTdarrReportText(text);
    final sections = TdarrReportSection.parse(
      normalized,
      failedReport: failedReport,
    );
    if (sections.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '${sections.length} sections',
            style: const TextStyle(color: LunaColours.blueGrey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...sections.map((section) => _TdarrReportSectionTile(section)),
        ],
      );
    }
    final lines = normalized.split('\n');
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${lines.length} lines',
              style: const TextStyle(color: LunaColours.blueGrey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [for (final line in lines) ..._lineSpans(line)],
              ),
              softWrap: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<TextSpan> _lineSpans(String line) {
    final severity = _severity(line);
    final timestamp = RegExp(
      r'^((?:\[)?(?:\d{4}-\d{2}-\d{2}|\d{2}:\d{2}:\d{2})[^\s\]]*(?:\])?)\s*',
    ).firstMatch(line);
    final timestampText = timestamp?.group(0) ?? '';
    final message = line.substring(timestampText.length);

    return [
      if (timestampText.isNotEmpty)
        TextSpan(
          text: timestampText,
          style: const TextStyle(color: LunaColours.blueGrey),
        ),
      TextSpan(
        text: message,
        style: TextStyle(
          color: severity.color,
          fontWeight: severity.emphasize ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      const TextSpan(text: '\n'),
    ];
  }

  static _TdarrReportLineStyle _severity(String line) {
    final normalized = line.toLowerCase();
    if (isTdarrErrorLine(line)) {
      return const _TdarrReportLineStyle(LunaColours.red, true);
    }
    if (normalized.contains('warn')) {
      return const _TdarrReportLineStyle(LunaColours.orange, true);
    }
    if (normalized.contains('success') ||
        normalized.contains('complete') ||
        normalized.contains('finished')) {
      return const _TdarrReportLineStyle(LunaColours.accent, false);
    }
    return const _TdarrReportLineStyle(Colors.white, false);
  }
}

class _TdarrReportLineStyle {
  final Color color;
  final bool emphasize;

  const _TdarrReportLineStyle(this.color, this.emphasize);
}

class TdarrReportSection {
  final String step;
  final String source;
  final String title;
  final String? duration;
  final List<String> lines;
  final bool failed;

  const TdarrReportSection({
    required this.step,
    required this.source,
    required this.title,
    required this.duration,
    required this.lines,
    required this.failed,
  });

  static List<TdarrReportSection> parse(
    String text, {
    bool failedReport = false,
  }) {
    final sections = <TdarrReportSection>[];
    final current = <String>[];
    String? currentStep;

    void finish() {
      if (currentStep == null || current.isEmpty) return;
      final heading = current.first.trim();
      final stepMatch = RegExp(r'\[Step\s+([^\]]+)\]').firstMatch(heading)!;
      final source = heading
          .substring(0, stepMatch.start)
          .replaceFirst(RegExp(r':$'), '');
      final title = heading.substring(stepMatch.end).trim();
      final duration = current
          .skip(1)
          .map((line) => line.trim())
          .firstWhere(_isDuration, orElse: () => '');
      sections.add(
        TdarrReportSection(
          step: stepMatch.group(1)!,
          source: source,
          title: title.isEmpty ? heading : title,
          duration: duration.isEmpty ? null : duration,
          lines: List<String>.unmodifiable(current),
          failed: failedReport && _hasTerminalFailure(current),
        ),
      );
      current.clear();
    }

    for (final line in text.split('\n')) {
      final match = RegExp(r'\[Step\s+[^\]]+\]').firstMatch(line);
      if (match != null) {
        finish();
        currentStep = match.group(0);
        current.add(line);
      } else if (currentStep == null) {
        continue;
      } else {
        current.add(line);
      }
    }
    finish();
    return sections;
  }

  static bool _isDuration(String line) => RegExp(
    r'^\d+(?:\.\d+)?(?:ms|s|m|h)(?:\s+\d+(?:\.\d+)?(?:ms|s|m|h))*$',
  ).hasMatch(line);

  /// Tdarr's terminal error marker identifies the event which actually ended
  /// the job. Words such as `onFlowError` are routine flow names and must not
  /// turn an otherwise successful step red.
  static bool _hasTerminalFailure(List<String> lines) => lines.any(
    (line) => RegExp(
      r'\[\s*-(?:error|fail(?:ed)?)\s*-\]|job\s+end\s+with\s+(?:an?\s+)?error',
      caseSensitive: false,
    ).hasMatch(line),
  );
}

class _TdarrReportSectionTile extends StatelessWidget {
  final TdarrReportSection section;

  const _TdarrReportSectionTile(this.section);

  @override
  Widget build(BuildContext context) {
    final color = section.failed ? LunaColours.red : LunaColours.accent;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: Icon(
          section.failed ? Icons.cancel_rounded : Icons.check_circle_rounded,
          color: color,
        ),
        title: Text(
          '[${section.step}] ${section.title}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (section.source.isNotEmpty) section.source,
            if (section.duration != null) section.duration!,
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SelectableText.rich(
            TextSpan(
              children: [
                for (final line in section.lines)
                  ...TdarrReportText._lineSpans(line),
              ],
            ),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
