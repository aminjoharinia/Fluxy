import 'package:flutter/widgets.dart';

/// A [Navigator] for GetX pages.
///
/// It does **not** add a [HeroController] to its observers. A Navigator takes
/// its hero controller from the closest [HeroControllerScope]:
/// `MaterialApp` / `CupertinoApp` already provide one with a stable instance.
/// Adding a second controller here gave every hero two flights for the same
/// tag, and creating it per build swapped it out mid-flight on rebuilds.
///
/// Wrap a navigator in [FluxyHeroScope] when it has no app scope above it, or
/// when it is nested under another navigator (a scope's controller can serve
/// only one navigator at a time).
class FluxyNavigator extends Navigator {
  FluxyNavigator({
    super.key,
    bool Function(Route<dynamic>, dynamic)? onPopPage,
    required super.pages,
    List<NavigatorObserver>? observers,
    super.reportsRouteUpdateToEngine,
    TransitionDelegate? transitionDelegate,
    super.initialRoute,
    super.restorationScopeId,
  }) : super(
          // ignore: deprecated_member_use
          onPopPage: onPopPage ??
              (route, result) {
                final didPop = route.didPop(result);
                if (!didPop) {
                  return false;
                }
                return true;
              },
          observers: [
            ...?observers,
          ],
          transitionDelegate:
              transitionDelegate ?? const DefaultTransitionDelegate<dynamic>(),
        );
}

/// Gives [child]'s navigator a [HeroController] that is created once and kept
/// for the life of this widget.
///
/// With [nested] false (the root navigator), an existing [HeroControllerScope]
/// above, such as the one `MaterialApp` provides, is used as is, and a
/// controller is created only when there is none. With [nested] true, the
/// navigator always gets its own controller, because the parent navigator
/// already holds the outer one.
class FluxyHeroScope extends StatefulWidget {
  const FluxyHeroScope({
    super.key,
    required this.child,
    this.nested = false,
    this.createRectTween,
  });

  final Widget child;
  final bool nested;
  final CreateRectTween? createRectTween;

  @override
  State<FluxyHeroScope> createState() => _GetHeroScopeState();
}

class _GetHeroScopeState extends State<FluxyHeroScope> {
  HeroController? _controller;

  @override
  Widget build(BuildContext context) {
    if (!widget.nested && HeroControllerScope.maybeOf(context) != null) {
      return widget.child;
    }
    final controller = _controller ??= HeroController(
      createRectTween: widget.createRectTween,
    );
    return HeroControllerScope(controller: controller, child: widget.child);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
