import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:material_ui/material_ui.dart';

class _Counter extends StatefulWidget {
  const _Counter(this.label);
  final String label;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int builds = 0;
  @override
  Widget build(BuildContext context) =>
      Text('${widget.label} ${++builds}', textDirection: TextDirection.ltr);
}

void main() {
  testWidgets('a rebuilt FluxyApp shows its new home', (tester) async {
    await tester.pumpWidget(FluxyApp(home: const Text('first')));
    expect(find.text('first'), findsOneWidget);
    await tester.pumpWidget(FluxyApp(home: const Text('second')));
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });

  testWidgets('a home of the same type is updated in place (state kept)',
      (tester) async {
    await tester.pumpWidget(FluxyApp(home: const _Counter('a')));
    expect(find.text('a 1'), findsOneWidget);
    await tester.pumpWidget(FluxyApp(home: const _Counter('b')));
    expect(find.text('b 2'), findsOneWidget);
  });

  testWidgets('a rebuilt FluxyApp takes a new theme', (tester) async {
    late BuildContext ctx;
    Widget app(Brightness b) => FluxyApp(
          theme: ThemeData(brightness: b),
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        );
    await tester.pumpWidget(app(Brightness.light));
    expect(Theme.of(ctx).brightness, Brightness.light);
    await tester.pumpWidget(app(Brightness.dark));
    await tester.pumpAndSettle();
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });

  testWidgets('changeThemeMode survives a rebuild that passes the same theme',
      (tester) async {
    late BuildContext ctx;
    Widget app() => FluxyApp(
          theme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
          themeMode: ThemeMode.light,
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        );
    await tester.pumpWidget(app());
    Fluxy.changeThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(Theme.of(ctx).brightness, Brightness.dark);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(Theme.of(ctx).brightness, Brightness.dark);
  });
}
