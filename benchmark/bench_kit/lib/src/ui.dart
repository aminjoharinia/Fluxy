import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'harness.dart';
import 'widgets.dart';

/// Light / dark / follow the system; the header's sun / moon button flips it.
final _themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

/// One color per library, used for its bars, dots and legend everywhere.
Color libraryColor(String name) {
  final n = name.toLowerCase();
  if (n.contains('fluxy')) return const Color(0xFF8B5CF6); // violet
  if (n.contains('getx 5') || n.contains('getx5')) {
    return const Color(0xFFF59E0B); // amber
  }
  if (n.contains('getx')) return const Color(0xFFF97316); // orange
  if (n.contains('riverpod')) return const Color(0xFF0EA5E9); // sky
  if (n.contains('bloc')) return const Color(0xFF10B981); // emerald
  if (n.contains('signals')) return const Color(0xFFEC4899); // pink
  return const Color(0xFF64748B); // slate
}

const _groupColors = {
  'core': [Color(0xFF6366F1), Color(0xFF06B6D4)],
  'widget': [Color(0xFFEC4899), Color(0xFFF59E0B)],
};

const _scenarioIcons = <String, IconData>{
  'create': Icons.add_circle_outline,
  'write': Icons.edit_outlined,
  'fanout': Icons.call_split,
  'wide': Icons.view_week_outlined,
  'chain': Icons.link,
  'diamond': Icons.diamond_outlined,
  'batch': Icons.layers_outlined,
  'mount': Icons.dashboard_customize_outlined,
  'rebuildAll': Icons.refresh,
  'rebuildOne': Icons.ads_click,
};

const _sizeIcons = <BenchSize, IconData>{
  BenchSize.tiny: Icons.phone_iphone,
  BenchSize.normal: Icons.tablet_mac,
  BenchSize.heavy: Icons.laptop_mac,
  BenchSize.superApp: Icons.rocket_launch_outlined,
};

/// The benchmark app when it is opened by hand: a Run button, progress, an
/// app-size picker, and one bar chart per scenario comparing this run with
/// the saved results of every library at that size (`results/summary.json`,
/// `results/<size>/summary.json`), plus the correctness table.
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
            seedColor: libraryColor(library),
            brightness: brightness,
          ),
          visualDensity: VisualDensity.compact,
        );
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: '$library benchmark',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: mode,
        home: _BenchPage(app: this),
      ),
    );
  }
}

/// The `benchmark/` directory (it has `bench_kit/` and `results/`), found by
/// walking up from the app's executable (it lives under
/// `benchmark/apps/<lib>/build/...`) or the working directory.
Directory? _findBenchRoot() {
  for (final start in [
    File(Platform.resolvedExecutable).parent,
    Directory.current,
  ]) {
    var dir = start;
    for (var i = 0; i < 14; i++) {
      if (Directory('${dir.path}/results').existsSync() &&
          Directory('${dir.path}/bench_kit').existsSync()) {
        return dir;
      }
      if (dir.parent.path == dir.path) break;
      dir = dir.parent;
    }
  }
  return null;
}

/// The saved results for [size]: `results/summary.json` for normal (or
/// `--dart-define=BENCH_SUMMARY=...`), `results/<size>/summary.json` for the
/// others (written by `SIZE=<size> run.sh`).
File? _findSummary(BenchSize size) {
  const override = String.fromEnvironment('BENCH_SUMMARY');
  if (size == BenchSize.normal && override.isNotEmpty) return File(override);
  final root = _findBenchRoot();
  if (root == null) return null;
  return File(size == BenchSize.normal
      ? '${root.path}/results/summary.json'
      : '${root.path}/results/${size.key}/summary.json');
}

class _SavedLibrary {
  _SavedLibrary(this.name, this.results);
  final String name;
  final Map<String, Map<String, Object?>> results;
}

class _Saved {
  const _Saved(this.libraries, this.machine, this.file);
  final List<_SavedLibrary> libraries;
  final String? machine;
  final File? file;

  static _Saved load(BenchSize size) {
    final file = _findSummary(size);
    if (file == null || !file.existsSync()) return _Saved(const [], null, file);
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final machine = json['machine'] as Map<String, Object?>?;
      return _Saved([
        for (final lib in (json['libraries'] as List).cast<Map>())
          _SavedLibrary(lib['library'] as String, {
            for (final r in (lib['results'] as List).cast<Map>())
              r['id'] as String: r.cast<String, Object?>(),
          }),
      ], machine?['cpu'] as String?, file);
    } catch (_) {
      return _Saved(const [], null, file);
    }
  }
}

class _BenchPage extends StatefulWidget {
  const _BenchPage({required this.app});
  final BenchApp app;

  @override
  State<_BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<_BenchPage> {
  /// This session's runs, per size.
  final _runs = <BenchSize, Map<String, Map<String, Object?>>>{};
  final _savedBySize = <BenchSize, _Saved>{};
  var _size = BenchSize.normal;
  String? _running;
  bool _busy = false;

  static const _release = bool.fromEnvironment('dart.vm.product');

  Map<String, Map<String, Object?>> get _results =>
      _runs.putIfAbsent(_size, () => {});
  _Saved get _saved => _savedBySize.putIfAbsent(_size, () => _Saved.load(_size));

  Future<void> _run() async {
    final size = _size;
    final results = _runs.putIfAbsent(size, () => {});
    setState(() {
      _busy = true;
      results.clear();
    });
    Future<void> start(String id) async {
      setState(() => _running = id);
      // Let the progress show before the scenario takes the thread.
      await WidgetsBinding.instance.endOfFrame;
    }

    void result(Map<String, Object?> r) => results[r['id'] as String] = r;
    try {
      await runCore(widget.app.core,
          size: size, onStart: start, onResult: result);
      await runWidgets(widget.app.widgets,
          size: size, onStart: start, onResult: result);
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
          SliverToBoxAdapter(child: _legend(context)),
          for (final group in const ['core', 'widget']) ...[
            SliverToBoxAdapter(child: _groupTitle(context, group)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(builder: (context, constraints) {
                  const gap = 12.0;
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

  Widget _groupTitle(BuildContext context, String group) {
    final colors = _groupColors[group]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Row(children: [
        Container(
          width: 6,
          height: 22,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        ShaderMask(
          shaderCallback: (r) => LinearGradient(colors: colors).createShader(r),
          child: Text(
            group == 'core' ? 'Core reactivity' : 'Widgets',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }

  Widget _header(BuildContext context, int done, int total) {
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = libraryColor(widget.app.library);
    final runningTitle = _running == null
        ? null
        : scenarioInfos.firstWhere((s) => s.id == _running).title;
    const onHeader = Colors.white;
    final saved = _saved;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  Color.lerp(accent, Colors.black, 0.45)!,
                  const Color(0xFF1E1B4B),
                  const Color(0xFF831843),
                ]
              : [accent, const Color(0xFF6366F1), const Color(0xFFEC4899)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
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
                        style: text.headlineSmall?.copyWith(
                            color: onHeader, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(widget.app.notes,
                        style: text.bodySmall?.copyWith(
                            color: onHeader.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              // Where the widget scenarios render their leaves.
              Tooltip(
                message: 'Widget scenarios render here',
                child: Container(
                  width: 200,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: benchHost()),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: dark ? 'Light mode' : 'Dark mode',
                onPressed: () => _themeMode.value =
                    dark ? ThemeMode.light : ThemeMode.dark,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: onHeader,
                ),
                icon: Icon(dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _run,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: accent,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
                  disabledForegroundColor: onHeader,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                icon: Icon(_busy ? Icons.hourglass_top : Icons.play_arrow),
                label: Text(_busy
                    ? 'Running'
                    : _results.isEmpty
                        ? 'Run'
                        : 'Run again'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sizePicker(context),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 8, color: Colors.white.withValues(alpha: 0.25)),
              FractionallySizedBox(
                widthFactor: total == 0 ? 0 : done / total,
                child: Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0xFFFDE68A),
                      Color(0xFFFFFFFF),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text(
            _busy
                ? 'Running ${runningTitle ?? ''} (${done + 1} of $total) '
                    'at ${_size.label.toLowerCase()} size…'
                : done == total
                    ? 'Done. Each scenario: ${_size.warmup} warm-up runs, '
                        'then the median of ~2.5 s of samples (at least '
                        '${_size.minSamples}).'
                    : 'Pick an app size and press Run to measure this '
                        'library. The saved results below come from run.sh.',
            style: text.bodySmall?.copyWith(color: onHeader),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (!_release)
              _chip(context, 'Debug build: times are not meaningful, use '
                  'flutter run --release',
                  color: const Color(0xFFDC2626), icon: Icons.warning_amber),
            _chip(
                context,
                saved.libraries.isEmpty
                    ? 'No saved ${_size.label.toLowerCase()} results: '
                        'SIZE=${_size.key} benchmark/run.sh'
                    : 'Saved ${_size.label.toLowerCase()} results: '
                        '${saved.machine ?? 'summary.json'}',
                color: saved.libraries.isEmpty
                    ? const Color(0xFFB45309)
                    : const Color(0xFF047857),
                icon: saved.libraries.isEmpty
                    ? Icons.info_outline
                    : Icons.check_circle_outline),
            _chip(context,
                'This window repaints between scenarios; run.sh is quieter',
                icon: Icons.tune),
          ]),
        ],
      ),
    );
  }

  Widget _sizePicker(BuildContext context) {
    final accent = libraryColor(widget.app.library);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final size in BenchSize.values)
          _SizeButton(
            size: size,
            icon: _sizeIcons[size]!,
            selected: size == _size,
            accent: accent,
            onTap: _busy ? null : () => setState(() => _size = size),
          ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label,
      {Color? color, IconData? icon}) {
    final bg = color ?? Colors.white.withValues(alpha: 0.18);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white)),
      ]),
    );
  }

  Widget _legend(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final names = [
      for (final lib in _saved.libraries) lib.name,
      if (_saved.libraries.isEmpty) widget.app.library,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Wrap(spacing: 16, runSpacing: 8, children: [
        for (final name in names)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: libraryColor(name),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(name,
                style: text.labelMedium?.copyWith(
                    fontWeight: name == widget.app.library
                        ? FontWeight.w800
                        : FontWeight.w500)),
          ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events, size: 14, color: Color(0xFFF59E0B)),
          const SizedBox(width: 4),
          Text('fastest', style: text.labelMedium),
        ]),
      ]),
    );
  }

  Widget _scenarioCard(ScenarioInfo info) {
    final mine = _results[info.id];
    final bars = <_Bar>[
      _Bar(
        'This run',
        mine,
        color: libraryColor(widget.app.library),
        highlight: true,
        thisRun: true,
        running: _running == info.id,
      ),
      for (final lib in _saved.libraries)
        _Bar(lib.name, lib.results[info.id],
            color: libraryColor(lib.name),
            highlight: lib.name == widget.app.library),
    ];
    return _ScenarioCard(info: info, size: _size, bars: bars);
  }

  Widget _correctness(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final rows = <(String, Color, Map<String, Map<String, Object?>>)>[
      if (_results.isNotEmpty)
        ('This run', libraryColor(widget.app.library), _results),
      for (final lib in _saved.libraries)
        (lib.name, libraryColor(lib.name), lib.results),
    ];
    if (rows.isEmpty) return const SizedBox();
    String metric(Map<String, Map<String, Object?>> results, String id,
        String key) {
      final metrics = results[id]?['metrics'] as Map?;
      final value = metrics?[key] as num?;
      return value == null ? '–' : value.toStringAsFixed(1);
    }

    const good = Color(0xFF10B981);
    final bad = scheme.error;
    Widget cell(String c, {bool head = false, bool isBad = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Text(c,
              textAlign: TextAlign.end,
              style: (head ? text.labelMedium : text.bodySmall)?.copyWith(
                  fontWeight: head ? FontWeight.w700 : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isBad ? bad : null)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 6,
              height: 22,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [good, Color(0xFF06B6D4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text('Correctness',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          Text(
              'Ideal: 1 listener call and 0 glitches per diamond write, 1 '
              'listener call per batch round. Red rows did extra work or '
              'showed inconsistent values.',
              style: text.bodySmall),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxWidth: 760),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Table(
              columnWidths: const {0: FlexColumnWidth(2.2)},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration:
                      BoxDecoration(color: scheme.surfaceContainerHigh),
                  children: [
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Text('Library',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    cell('Diamond calls / write', head: true),
                    cell('Glitches / write', head: true),
                    cell('Batch calls / round', head: true),
                  ],
                ),
                for (final (name, color, results) in rows)
                  () {
                    final isBad = _isGlitchy(results);
                    return TableRow(
                      decoration: BoxDecoration(
                        color: isBad
                            ? scheme.error.withValues(alpha: 0.06)
                            : good.withValues(alpha: 0.05),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          child: Row(children: [
                            Icon(
                              isBad
                                  ? Icons.cancel_rounded
                                  : Icons.check_circle_rounded,
                              size: 16,
                              color: isBad ? bad : good,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(name,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        ),
                        cell(metric(results, 'diamond',
                                'listenerCallsPerWrite'),
                            isBad: isBad),
                        cell(metric(results, 'diamond', 'glitchesPerWrite'),
                            isBad: isBad),
                        cell(metric(results, 'batch', 'listenerCallsPerRound'),
                            isBad: isBad),
                      ],
                    );
                  }(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.size,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final BenchSize size;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = selected ? accent : Colors.white;
    return Tooltip(
      message: '${formatCount(size.widgets)} widgets, '
          '${formatCount(size.writes)} writes, '
          'chain of ${size.chainDepth}',
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null && !selected ? 0.55 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(size.label,
                        style: text.labelLarge?.copyWith(
                            color: fg, fontWeight: FontWeight.w700)),
                    Text('${formatCount(size.widgets)} widgets',
                        style: text.labelSmall?.copyWith(
                            color: fg.withValues(alpha: 0.8))),
                  ],
                ),
              ]),
            ),
          ),
        ),
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
  _Bar(
    this.label,
    this.result, {
    required this.color,
    this.highlight = false,
    this.thisRun = false,
    this.running = false,
  });
  final String label;
  final Map<String, Object?>? result;
  final Color color;
  final bool highlight;
  final bool thisRun;
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

/// One scenario: a horizontal bar per library in its own color, linear
/// scale, capped at [_cap] times the fastest so one very slow library does
/// not flatten the rest (a capped bar is drawn broken near its end; its
/// label says how many times slower it is).
class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard(
      {required this.info, required this.size, required this.bars});
  final ScenarioInfo info;
  final BenchSize size;
  final List<_Bar> bars;

  static const _cap = 8.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final groupColors = _groupColors[info.group]!;
    final times = [for (final b in bars) b.us].whereType<int>();
    final fastest = times.isEmpty ? 1 : times.reduce(math.min);
    final scale = fastest * _cap;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: groupColors.first.withValues(alpha: dark ? 0.35 : 0.18)),
        boxShadow: [
          BoxShadow(
            color: groupColors.first.withValues(alpha: dark ? 0.18 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: groupColors),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: groupColors),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(_scenarioIcons[info.id] ?? Icons.speed,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(info.title,
                        style: text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(info.describe(size),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                for (final bar in bars) _row(context, bar, fastest, scale),
                if (bars.any((b) => b.wrong))
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      info.id == 'diamond'
                          ? '⚠ fast but wrong: its listener saw inconsistent '
                              'values (glitches) and ran twice per write'
                          : '⚠ fast but wrong: notified once per write, not '
                              'once per round',
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _Bar bar, int fastest, double scale) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isFastest = bar.us == fastest && bar.us != null;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: bar.color,
              shape: bar.thisRun ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: bar.thisRun ? BorderRadius.circular(2) : null,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 124,
            child: Text(bar.label,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(
                    color: bar.thisRun ? bar.color : null,
                    fontWeight: bar.highlight ? FontWeight.w800 : null)),
          ),
          Expanded(child: _barTrack(context, bar, scale)),
          SizedBox(
            width: 18,
            child: isFastest
                ? const Icon(Icons.emoji_events,
                    size: 15, color: Color(0xFFF59E0B))
                : null,
          ),
          SizedBox(
            width: 104,
            child: Text(
              _valueLabel(bar, fastest),
              textAlign: TextAlign.end,
              style: text.labelMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: isFastest ? FontWeight.w800 : null,
                color: bar.error != null || bar.wrong
                    ? scheme.error
                    : isFastest
                        ? const Color(0xFFD97706)
                        : null,
              ),
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

  Widget _barTrack(BuildContext context, _Bar bar, double scale) {
    final scheme = Theme.of(context).colorScheme;
    final us = bar.us;
    final base = bar.color;
    final faded = bar.highlight ? 1.0 : 0.82;
    final gradient = LinearGradient(colors: [
      Color.lerp(base, Colors.white, 0.35)!.withValues(alpha: faded),
      base.withValues(alpha: faded),
    ]);
    final glow = bar.thisRun
        ? [
            BoxShadow(
              color: base.withValues(alpha: 0.45),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ]
        : null;
    final height = bar.thisRun ? 14.0 : 11.0;
    final radius = BorderRadius.circular(height / 2);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (us == null) {
        if (bar.running) {
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  color: base,
                  backgroundColor: base.withValues(alpha: 0.15),
                ),
              ),
            ),
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 6,
            width: width,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }
      if (us > scale) {
        // Off the scale: a broken bar (full length with a gap near the end).
        return Row(children: [
          Expanded(
            flex: 90,
            child: Container(
                height: height,
                decoration: BoxDecoration(
                    gradient: gradient, borderRadius: radius, boxShadow: glow)),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 6,
            child: Container(
                height: height,
                decoration: BoxDecoration(
                    color: base.withValues(alpha: faded),
                    borderRadius: radius)),
          ),
        ]);
      }
      final fraction = math.max(us / scale, 0.015);
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          height: height,
          width: width * fraction,
          decoration: BoxDecoration(
              gradient: gradient, borderRadius: radius, boxShadow: glow),
        ),
      );
    });
  }
}
