import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_i18n/fluxy_i18n.dart';
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

  testWidgets('a FluxyApp replaced by a new one (new key) leaves it working',
      (tester) async {
    // The old app is disposed after the new one has mounted; it must not
    // clear the root the new one registered.
    await tester.pumpWidget(FluxyApp(key: UniqueKey(), home: const Text('a')));
    await tester.pumpWidget(FluxyApp(key: UniqueKey(), home: const Text('b')));
    expect(tester.takeException(), isNull);
    expect(Fluxy.navigator, isNotNull);
    Fluxy.to(() => const Text('next'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('next'), findsOneWidget);
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

  // An app may build its FluxyApp inside an Obx on its language.
  group('a rebuilt FluxyApp takes a new locale', () {
    const tr = {
      'en_US': {'hi': 'Hello'},
      'fa_IR': {'hi': 'Salam'},
    };
    Widget app(Locale locale, {Locale? fallback}) => FluxyApp(
          translationsKeys: tr,
          locale: locale,
          fallbackLocale: fallback,
          home: const _Hi(),
        );

    testWidgets('const widgets reading .tr show the new language',
        (tester) async {
      await tester.pumpWidget(app(const Locale('en', 'US')));
      expect(find.text('Hello'), findsOneWidget);
      await tester.pumpWidget(app(const Locale('fa', 'IR')));
      expect(Fluxy.locale, const Locale('fa', 'IR'));
      await tester.pumpAndSettle();
      expect(find.text('Salam'), findsOneWidget);
      expect(find.text('Hello'), findsNothing);
    });

    testWidgets('updateLocale survives a rebuild that passes the same locale',
        (tester) async {
      await tester.pumpWidget(app(const Locale('en', 'US')));
      Fluxy.updateLocale(const Locale('fa', 'IR'));
      await tester.pumpAndSettle();
      expect(find.text('Salam'), findsOneWidget);
      await tester.pumpWidget(app(const Locale('en', 'US')));
      await tester.pumpAndSettle();
      expect(Fluxy.locale, const Locale('fa', 'IR'));
      expect(find.text('Salam'), findsOneWidget);
    });

    testWidgets('a changed fallbackLocale is applied', (tester) async {
      const other = Locale('de', 'DE');
      await tester.pumpWidget(app(other, fallback: const Locale('en', 'US')));
      expect(find.text('Hello'), findsOneWidget);
      await tester.pumpWidget(app(other, fallback: const Locale('fa', 'IR')));
      await tester.pumpAndSettle();
      expect(Fluxy.fallbackLocale, const Locale('fa', 'IR'));
      expect(find.text('Salam'), findsOneWidget);
    });
  });

  // An app's boot may apply the saved dark mode before FluxyApp is
  // built; GetX 4 kept it, Fluxy threw).
  group('theme changes before FluxyApp is mounted', () {
    tearDown(Fluxy.reset);
    late BuildContext ctx;
    Widget app({ThemeMode mode = ThemeMode.light}) => FluxyApp(
          theme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
          themeMode: mode,
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
        );

    testWidgets('changeThemeMode during boot is applied on mount',
        (tester) async {
      Fluxy.changeThemeMode(ThemeMode.dark); // no app yet: kept, no throw
      await tester.pumpWidget(app());
      expect(Theme.of(ctx).brightness, Brightness.dark);
      // Kept until the app passes a different mode, like a call after mount.
      await tester.pumpWidget(app());
      expect(Theme.of(ctx).brightness, Brightness.dark);
      await tester.pumpWidget(app(mode: ThemeMode.system));
      await tester.pumpWidget(app(mode: ThemeMode.light));
      await tester.pumpAndSettle(); // the theme animates
      expect(Theme.of(ctx).brightness, Brightness.light);
    });

    testWidgets('changeTheme during boot is applied on mount', (tester) async {
      Fluxy.changeTheme(ThemeData(
          brightness: Brightness.light, primaryColor: const Color(0xFF123456)));
      await tester.pumpWidget(app());
      expect(Theme.of(ctx).primaryColor, const Color(0xFF123456));
    });

    testWidgets('a change between an unmount and a remount is kept',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpWidget(const SizedBox());
      Fluxy.changeThemeMode(ThemeMode.dark);
      await tester.pumpWidget(app());
      expect(Theme.of(ctx).brightness, Brightness.dark);
    });

    testWidgets('Fluxy.reset forgets a kept change', (tester) async {
      Fluxy.changeThemeMode(ThemeMode.dark);
      Fluxy.reset();
      await tester.pumpWidget(app());
      expect(Theme.of(ctx).brightness, Brightness.light);
    });
  });
}


class _Hi extends StatelessWidget {
  const _Hi();
  @override
  Widget build(BuildContext context) => Text('hi'.tr);
}
