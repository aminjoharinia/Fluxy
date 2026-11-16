import 'dart:io';

import 'package:bench_kit/bench_kit.dart';
import 'package:bench_kit/src/ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
}

class _NoWidgets extends WidgetSuite {
  @override
  void setup(int n) {}
  @override
  Widget leaf(int i) => Leaf(i);
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
    // Set BENCH_UI_PREVIEW=1 with --update-goldens to write a PNG to look at.
    if (preview) {
      await expectLater(
          find.byType(BenchApp), matchesGoldenFile('ui_preview.png'));
    }

  });
}
