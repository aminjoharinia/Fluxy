import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'harness.dart';
import 'widgets.dart';

/// The benchmark app when it is opened by hand: a Run button, progress, and
/// one bar chart per scenario comparing this run with the saved results of
/// every library (`results/summary.json`), plus the correctness table.
///
/// `run.sh` never shows this (it builds with `BENCH_OUT` and runs headless),
/// so the published numbers do not include the window repainting between
/// scenarios.
class BenchApp extends StatelessWidget {
  const BenchApp({
    super.key,
    required this.library,
    required this.notes,
    required this.core,
    required this.widgets,
  });

  final String library;
  final String notes;
  final CoreSuite core;
  final WidgetSuite widgets;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B6FD8),
            brightness: brightness,
          ),
          visualDensity: VisualDensity.compact,
        );
    return MaterialApp(
      title: '$library benchmark',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: _BenchPage(app: this),
    );
  }
}

/// `results/summary.json`, found by walking up from the app's executable
/// (it lives under `benchmark/apps/<lib>/build/...`), or given with
/// `--dart-define=BENCH_SUMMARY=...`.
File? _findSummary() {
  const override = String.fromEnvironment('BENCH_SUMMARY');
  if (override.isNotEmpty) return File(override);
  for (final start in [
    File(Platform.resolvedExecutable).parent,
    Directory.current,
  ]) {
    var dir = start;
    for (var i = 0; i < 14; i++) {
      final file = File('${dir.path}/results/summary.json');
      if (file.existsSync() &&
          Directory('${dir.path}/bench_kit').existsSync()) {
        return file;
      }
      if (dir.parent.path == dir.path) break;
      dir = dir.parent;
    }
  }
  return null;
}

class _SavedLibrary {
  _SavedLibrary(this.name, this.results);
  final String name;
  final Map<String, Map<String, Object?>> results;
}

class _BenchPage extends StatefulWidget {
  const _BenchPage({required this.app});
  final BenchApp app;

  @override
  State<_BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<_BenchPage> {
  final _results = <String, Map<String, Object?>>{};
  List<_SavedLibrary> _saved = const [];
  String? _savedFrom;
  String? _savedMachine;
  String? _running;
  bool _busy = false;

  static const _release = bool.fromEnvironment('dart.vm.product');

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary() {
    final file = _findSummary();
    if (file == null || !file.existsSync()) return;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final machine = json['machine'] as Map<String, Object?>?;
      _savedMachine = machine?['cpu'] as String?;
      _savedFrom = file.path;
      _saved = [
        for (final lib in (json['libraries'] as List).cast<Map>())
          _SavedLibrary(lib['library'] as String, {
            for (final r in (lib['results'] as List).cast<Map>())
              r['id'] as String: r.cast<String, Object?>(),
          }),
      ];
    } catch (_) {
      _saved = const [];
    }
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _results.clear();
    });
    Future<void> start(String id) async {
      setState(() => _running = id);
      // Let the progress show before the scenario takes the thread.
      await WidgetsBinding.instance.endOfFrame;
    }

    void result(Map<String, Object?> r) => _results[r['id'] as String] = r;
    try {
      await runCore(widget.app.core, onStart: start, onResult: result);
      await runWidgets(widget.app.widgets, onStart: start, onResult: result);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _running = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = _results.length;
    final total = scenarioInfos.length;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(context, done, total)),
          for (final group in const ['core', 'widget']) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  group == 'core' ? 'Core reactivity' : 'Widgets',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(builder: (context, constraints) {
                  const gap = 8.0;
                  final columns =
                      math.max(1, (constraints.maxWidth + gap) ~/ (520 + gap));
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final info in scenarioInfos)
                        if (info.group == group)
                          SizedBox(width: width, child: _scenarioCard(info)),
                    ],
                  );
                }),
              ),
            ),
          ],
          SliverToBoxAdapter(child: _correctness(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, int done, int total) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final runningTitle = _running == null
        ? null
        : scenarioInfos.firstWhere((s) => s.id == _running).title;
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.app.library} benchmark',
                        style: text.headlineSmall),
                    const SizedBox(height: 2),
                    Text(widget.app.notes,
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              // Where the widget scenarios render their 1,000 leaves.
              Tooltip(
                message: 'Widget scenarios render here',
                child: Container(
                  width: 200,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: ClipRect(child: benchHost()),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: _busy ? null : _run,
                child: Text(_results.isEmpty ? 'Run' : 'Run again'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: total == 0 ? 0 : done / total,
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          const SizedBox(height: 8),
          Text(
            _busy
                ? 'Running ${runningTitle ?? ''} (${done + 1} of $total)…'
                : done == total
                    ? 'Done. Each scenario: 5 warm-up runs, then the median '
                        'of ~2.5 s of samples.'
                    : 'Press Run to measure this library. The saved results '
                        'below come from run.sh.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (!_release)
              _chip(context, 'Debug build: times are not meaningful, use '
                  'flutter run --release', warning: true),
            _chip(
                context,
                _savedFrom == null
                    ? 'No results/summary.json found'
                    : 'Saved results: ${_savedMachine ?? 'summary.json'}'),
            _chip(context,
                'This window repaints between scenarios; run.sh is quieter'),
          ]),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, {bool warning = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warning ? scheme.errorContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: warning
                  ? scheme.onErrorContainer
                  : scheme.onSurfaceVariant)),
    );
  }

  Widget _scenarioCard(ScenarioInfo info) {
    final mine = _results[info.id];
    final bars = <_Bar>[
      _Bar(
        'This run',
        mine,
        highlight: true,
        running: _running == info.id,
      ),
      for (final lib in _saved)
        _Bar(lib.name, lib.results[info.id],
            highlight: lib.name == widget.app.library),
    ];
    return _ScenarioCard(info: info, bars: bars);
  }

  Widget _correctness(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final rows = <(String, Map<String, Map<String, Object?>>)>[
      if (_results.isNotEmpty) ('This run', _results),
      for (final lib in _saved) (lib.name, lib.results),
    ];
    if (rows.isEmpty) return const SizedBox();
    String metric(Map<String, Map<String, Object?>> results, String id,
        String key) {
      final metrics = results[id]?['metrics'] as Map?;
      final value = metrics?[key] as num?;
      return value == null ? '–' : value.toStringAsFixed(1);
    }

    TableRow row(List<String> cells, {bool head = false, bool bad = false}) =>
        TableRow(children: [
          for (final (i, c) in cells.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Text(c,
                  textAlign: i == 0 ? TextAlign.start : TextAlign.end,
                  style: (head ? text.labelMedium : text.bodySmall)?.copyWith(
                      color: bad && i > 0 ? scheme.error : null)),
            ),
        ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Correctness', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
              'Ideal: 1 listener call and 0 glitches per diamond write, 1 '
              'listener call per batch round. Red rows did extra work or '
              'showed inconsistent values.',
              style: text.bodySmall),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 720),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(2)},
              children: [
                row([
                  'Library',
                  'Diamond calls / write',
                  'Glitches / write',
                  'Batch calls / round',
                ], head: true),
                for (final (name, results) in rows)
                  row([
                    name,
                    metric(results, 'diamond', 'listenerCallsPerWrite'),
                    metric(results, 'diamond', 'glitchesPerWrite'),
                    metric(results, 'batch', 'listenerCallsPerRound'),
                  ], bad: _isGlitchy(results)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isGlitchy(Map<String, Map<String, Object?>> results) {
  num? m(String id, String key) =>
      (results[id]?['metrics'] as Map?)?[key] as num?;
  return (m('diamond', 'glitchesPerWrite') ?? 0) > 0 ||
      (m('batch', 'listenerCallsPerRound') ?? 1) > 1.5;
}

class _Bar {
  _Bar(this.label, this.result, {this.highlight = false, this.running = false});
  final String label;
  final Map<String, Object?>? result;
  final bool highlight;
  final bool running;

  bool get ok => result?['ok'] == true;

  /// The library got this scenario's result wrong in a way the timing does
  /// not show (diamond glitches, a batch notifying once per write).
  bool get wrong {
    final metrics = result?['metrics'] as Map?;
    if (metrics == null) return false;
    return ((metrics['glitchesPerWrite'] as num?) ?? 0) > 0 ||
        ((metrics['listenerCallsPerRound'] as num?) ?? 1) > 1.5;
  }
  int? get us => ok ? result!['medianUs'] as int : null;
  String? get error => result != null && !ok ? '${result!['error']}' : null;
}

String _formatUs(int us) {
  if (us < 1000) return '$us µs';
  if (us < 1000000) return '${(us / 1000).toStringAsFixed(2)} ms';
  return '${(us / 1000000).toStringAsFixed(2)} s';
}

/// One scenario: a horizontal bar per library, linear scale, capped at
/// [_cap] times the fastest so one very slow library does not flatten the
/// rest (a capped bar is drawn broken near its end; its label says how many
/// times slower it is).
class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.info, required this.bars});
  final ScenarioInfo info;
  final List<_Bar> bars;

  static const _cap = 8.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final times = [for (final b in bars) b.us].whereType<int>();
    final fastest = times.isEmpty ? 1 : times.reduce(math.min);
    final scale = fastest * _cap;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.title, style: text.titleSmall),
          const SizedBox(height: 2),
          Text(info.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          for (final bar in bars)
            SizedBox(
              height: 26,
              child: Row(
                children: [
                  SizedBox(
                    width: 132,
                    child: Text(bar.label,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium?.copyWith(
                            fontWeight:
                                bar.highlight ? FontWeight.w700 : null)),
                  ),
                  Expanded(
                    child: _barTrack(context, bar, fastest, scale),
                  ),
                  SizedBox(
                    width: 112,
                    child: Text(
                      _valueLabel(bar, fastest),
                      textAlign: TextAlign.end,
                      style: text.labelMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontWeight: bar.us == fastest && bar.us != null
                            ? FontWeight.w700
                            : null,
                        color: bar.error != null || bar.wrong
                            ? scheme.error
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (bars.any((b) => b.wrong))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                info.id == 'diamond'
                    ? '⚠ fast but wrong: its listener saw inconsistent values '
                        '(glitches) and ran twice per write'
                    : '⚠ fast but wrong: notified once per write, not once '
                        'per round',
                style: text.labelSmall?.copyWith(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }

  String _valueLabel(_Bar bar, int fastest) {
    if (bar.running) return 'running…';
    if (bar.error != null) return 'failed';
    final us = bar.us;
    if (us == null) return '–';
    final ratio = us / fastest;
    final mark = bar.wrong ? '⚠ ' : '';
    if (ratio < 1.05) return '$mark${_formatUs(us)}';
    final times = ratio.toStringAsFixed(ratio < 10 ? 1 : 0);
    return '$mark${_formatUs(us)}  $times×';
  }

  Widget _barTrack(BuildContext context, _Bar bar, int fastest, double scale) {
    final scheme = Theme.of(context).colorScheme;
    final us = bar.us;
    final color = bar.highlight ? scheme.primary : scheme.outline;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (us == null) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 1,
            width: width,
            color: scheme.outlineVariant,
          ),
        );
      }
      final radius = BorderRadius.circular(3);
      if (us > scale) {
        // Off the scale: a broken bar (full length with a gap near the end).
        return Row(children: [
          Expanded(
            flex: 90,
            child: Container(
                height: 12,
                decoration: BoxDecoration(color: color, borderRadius: radius)),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 6,
            child: Container(
                height: 12,
                decoration: BoxDecoration(color: color, borderRadius: radius)),
          ),
        ]);
      }
      final fraction = math.max(us / scale, 0.01);
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: 12,
          width: width * fraction,
          decoration: BoxDecoration(color: color, borderRadius: radius),
        ),
      );
    });
  }
}
