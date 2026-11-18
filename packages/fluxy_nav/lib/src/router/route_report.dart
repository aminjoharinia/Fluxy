import 'package:material_ui/material_ui.dart';

import 'package:fluxy_state/fluxy_state.dart';

/// Gives [builder]'s subtree its own dependency scope (a [DependencyScope]):
/// [dependencies] register in it, and everything in it is closed when this
/// widget goes.
class RouteReport extends StatelessWidget {
  const RouteReport({super.key, required this.builder, this.dependencies});
  final WidgetBuilder builder;

  /// Registers the dependencies that live as long as this widget.
  final void Function()? dependencies;

  @override
  Widget build(BuildContext context) {
    return DependencyScope(
      dependencies: dependencies,
      child: Builder(builder: builder),
    );
  }
}
