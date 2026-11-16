/// Shared harness for the Fluxy state-management benchmarks: every library
/// implements [CoreSuite] and [WidgetSuite]; [runBenchmarks] times them the
/// same way and writes JSON.
library;

export 'src/harness.dart';
export 'src/widgets.dart';
