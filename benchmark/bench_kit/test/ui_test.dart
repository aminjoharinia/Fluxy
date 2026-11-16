import 'dart:io';

import 'package:bench_kit/bench_kit.dart';
import 'package:bench_kit/src/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme, IconButton;
import 'package:flutter_test/flutter_test.dart';

class _NoCore extends CoreSuite {
  @override
  bool get asyncNotify => false;
  Bench _none(int _) => Bench(run: () {}, opsPerRun: 1);
  @override
  Bench create(int n) => _none(n);
  @override
  Bench writeOneListener(int writes) => _none(writes);
  @override
  Bench fanOut(int listeners, int writes) => _none(writes);
  @override
  Bench wideDerived(int sources) => _none(sources);
  @override
  Bench deepChain(int depth, int writes) => _none(writes);
  @override
  Bench diamond(int writes) => _none(writes);
  @override
  Bench batchUpdate(int sources, int rounds) => _none(rounds);
  @override
  Bench subscribeShared(int listeners) => _none(listeners);
  @override
  MemoryProbe memory(int n) =>
      MemoryProbe(create: () {}, listen: () {}, dispose: () {});
}

class _NoWidgets extends WidgetSuite {
  @override
  void setup(int n) {}
  @override
  Widget leaf(int i) => Leaf(i);
  @override
  Widget sharedLeaf(int i) => Leaf(0);
  @override
  void write(int i, int value) {}
  @override
  void teardown() {}
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final bytes = File(p).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  // Renders the page with the saved results (found by walking up from the
  // test's working directory) without layout errors.
  testWidgets('benchmark UI renders the saved results', (tester) async {
    final preview = Platform.environment['BENCH_UI_PREVIEW'] == '1';
    const fonts = '/System/Library/Fonts/Supplemental';
    if (preview && File('$fonts/Arial.ttf').existsSync()) {
      await _loadFont('Roboto', ['$fonts/Arial.ttf', '$fonts/Arial Bold.ttf']);
    }
    tester.view.physicalSize = const Size(1320, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BenchApp(
      library: 'Fluxy',
      notes: 'Rx.addListener, glitch-free Computed, Get.batch, Obx',
      core: _NoCore(),
      widgets: _NoWidgets(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Fluxy benchmark'), findsOneWidget);
    expect(find.text('Wide derived'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The size picker rescales every scenario's description.
    expect(find.textContaining('1,000 sources summed'), findsOneWidget);
    await tester.tap(find.text('Heavy app'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2,500 sources summed'), findsOneWidget);
    await tester.tap(find.text('Normal app'));
    await tester.pumpAndSettle();

    // The theme button flips light and dark.
    final before = Theme.of(tester.element(find.text('Wide derived'))).brightness;
    await tester.tap(find.byTooltip(
        before == Brightness.dark ? 'Light mode' : 'Dark mode'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Wide derived'))).brightness,
        isNot(before));
    expect(tester.takeException(), isNull);
    if (preview) {
      await expectLater(
          find.byType(BenchApp), matchesGoldenFile('ui_preview_flipped.png'));
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
    }
    // Set BENCH_UI_PREVIEW=1 with --update-goldens to write a PNG to look at.
    if (preview) {
      await expectLater(
          find.byType(BenchApp), matchesGoldenFile('ui_preview.png'));
    }

  });
}
