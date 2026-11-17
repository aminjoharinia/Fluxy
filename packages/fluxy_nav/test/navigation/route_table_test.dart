import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_nav/fluxy_nav.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'package:material_ui/material_ui.dart';

FluxyPage p(String name, {List<FluxyPage> children = const []}) =>
    FluxyPage(name: name, page: () => const SizedBox(), children: children);

class _B extends Binding {
  _B(this.tag);
  final String tag;
  @override
  List<Bind> dependencies() => [];
  @override
  String toString() => tag;
}

void main() {
  group('priority', () {
    test('static beats :param whatever the order', () {
      final t = RouteTable([p('/:id'), p('/settings')]);
      expect(t.match('/settings').patterns.last, '/settings');
      expect(t.match('/42').patterns.last, '/:id');
      expect(t.match('/42').parameters, {'id': '42'});
    });

    test(':param beats a wildcard', () {
      final t = RouteTable([p('/files/*rest'), p('/files/:name')]);
      expect(t.match('/files/a').patterns.last, '/files/:name');
      final deep = t.match('/files/a/b/c');
      expect(deep.patterns.last, '/files/*rest');
      expect(deep.parameters, {'rest': 'a/b/c'});
    });

    test('backtracks when the static branch dead-ends', () {
      final t = RouteTable([p('/user/me'), p('/user/:id/edit')]);
      final m = t.match('/user/me/edit');
      expect(m.patterns.last, '/user/:id/edit');
      expect(m.parameters, {'id': 'me'});
    });

    test('each page names its own parameters', () {
      final t = RouteTable([p('/u/:id'), p('/u/:uid/posts')]);
      expect(t.match('/u/1').parameters, {'id': '1'});
      expect(t.match('/u/1/posts').parameters, {'uid': '1'});
    });

    test('first registration of the same pattern wins', () {
      final first = FluxyPage(name: '/a', page: () => const Text('1'));
      final second = FluxyPage(name: '/a', page: () => const Text('2'));
      final t = RouteTable([first, second]);
      expect(t.match('/a').page!.page, same(first.page));
    });
  });

  group('patterns', () {
    test('optional parameter', () {
      final t = RouteTable([p('/list/:page?')]);
      expect(t.match('/list').isUnknown, isFalse);
      expect(t.match('/list/3').parameters, {'page': '3'});
    });

    test('trailing slash, query, full URL', () {
      final t = RouteTable([p('/'), p('/Home')]);
      expect(t.match('/Home/').page!.name, '/Home');
      expect(t.match('/Home?tab=2').parameters, {'tab': '2'});
      expect(t.match('/Home?tab=2').location, '/Home?tab=2');
      expect(t.match('https://x.com/Home').location, '/Home');
      expect(t.match('').page!.name, '/');
    });

    test('only a page for the whole path matches', () {
      final t = RouteTable([p('/'), p('/Home')]);
      expect(t.match('/nope').isUnknown, isTrue);
      expect(t.match('/Home/x').isUnknown, isTrue);
    });

    test('path segments are decoded; path wins over query', () {
      final t = RouteTable([p('/item/:id')]);
      final m = t.match('/item/a%20b?id=7&x=1');
      expect(m.parameters, {'id': 'a b', 'x': '1'});
      expect(m.pathParameters, {'id': 'a b'});
    });

    test('case matters', () {
      final t = RouteTable([p('/Home')]);
      expect(t.match('/home').isUnknown, isTrue);
    });
  });

  group('children', () {
    test('flattened to full paths, branch is the parents on the path', () {
      final t = RouteTable([
        p(
          '/',
          children: [
            p(
              '/home',
              children: [
                p('/products', children: [p('/:id')]),
              ],
            ),
          ],
        ),
      ]);
      expect(t.routes.map((r) => r.name), [
        '/',
        '/home',
        '/home/products',
        '/home/products/:id',
      ]);
      final m = t.match('/home/products/9');
      expect(m.branch.map((b) => b.name), [
        '/',
        '/home',
        '/home/products',
        '/home/products/9',
      ]);
      expect(m.branch.map((b) => b.key), [
        const ValueKey('/'),
        const ValueKey('/home'),
        const ValueKey('/home/products'),
        const ValueKey('/home/products/9'),
      ]);
      expect(m.branch.every((b) => b.parameters!['id'] == '9'), isTrue);
    });

    test('inheritParentPath: false keeps the child name', () {
      final t = RouteTable([
        FluxyPage(
          name: '/a',
          page: () => const SizedBox(),
          children: [
            FluxyPage(
              name: '/b',
              inheritParentPath: false,
              page: () => const SizedBox(),
            ),
          ],
        ),
      ]);
      expect(t.contains('/b'), isTrue);
      expect(t.contains('/a/b'), isFalse);
    });

    test('children get the bindings of their parents, once', () {
      final t = RouteTable([
        FluxyPage(
          name: '/a',
          page: () => const SizedBox(),
          binding: _B('a'),
          children: [
            FluxyPage(
              name: '/b',
              page: () => const SizedBox(),
              bindings: [_B('b')],
              children: [
                FluxyPage(
                  name: '/c',
                  page: () => const SizedBox(),
                  binding: _B('c'),
                ),
              ],
            ),
          ],
        ),
      ]);
      expect(t['/a/b']!.bindings.map((b) => '$b'), ['b', 'a']);
      final c = t['/a/b/c']!;
      expect([...c.bindings.map((b) => '$b'), '${c.binding}'], ['b', 'a', 'c']);
      expect(t.childrenOf('/a').single.name, '/b');
    });
  });

  test('the table is not changed by Fluxy.to (B4)', () {
    final d = FluxyDelegate(pages: [p('/')]);
    final routes = d.routeTable.routes;
    expect(() => routes.add(p('/x')), throwsUnsupportedError);
  });

  tearDown(Fluxy.reset);
}
