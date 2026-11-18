import 'package:material_ui/material_ui.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

/// The registry, as handed to [Module.dependencies]. Registrations made
/// through it while the module starts belong to the module's scope.
class Dependencies {
  void lazyPut<S>(InstanceBuilderCallback<S> builder, {String? tag}) =>
      Fluxy.lazyPut<S>(builder, tag: tag);

  S call<S>() => find<S>();

  void spawn<S>(InstanceBuilderCallback<S> builder, {String? tag}) =>
      Fluxy.spawn<S>(builder, tag: tag);

  S find<S>({String? tag}) => Fluxy.find<S>(tag: tag);

  S put<S>(S dependency, {String? tag, bool permanent = false}) =>
      Fluxy.put<S>(dependency, tag: tag, permanent: permanent);

  bool delete<S>({String? tag, bool force = false}) =>
      Fluxy.delete<S>(tag: tag, force: force);

  void deleteAll({bool force = false}) => Fluxy.deleteAll(force: force);

  void reloadAll({bool force = false}) => Fluxy.reloadAll(force: force);

  void reload<S>({String? tag, bool force = false}) =>
      Fluxy.reload<S>(tag: tag, force: force);

  bool isRegistered<S>({String? tag}) => Fluxy.isRegistered<S>(tag: tag);

  bool isPrepared<S>({String? tag}) => Fluxy.isPrepared<S>(tag: tag);

  void replace<P>(P child, {String? tag}) => Fluxy.replace<P>(child, tag: tag);

  void lazyReplace<P>(InstanceBuilderCallback<P> builder, {String? tag}) =>
      Fluxy.lazyReplace<P>(builder, tag: tag);
}

abstract class Module extends StatefulWidget {
  const Module({super.key});

  Widget view(BuildContext context);

  void dependencies(Dependencies i);

  @override
  ModuleState createState() => ModuleState();
}

/// Runs [Module.dependencies] in a scope of its own, closed with the module.
class ModuleState extends State<Module> {
  late final FluxyScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = FluxyScope(
      name: '${widget.runtimeType}',
      parent: DependencyScope.maybeOf(context),
    );
    _scope.run(() => widget.dependencies(Dependencies()));
  }

  @override
  void dispose() {
    _scope.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScopeProvider(
      scope: _scope,
      child: Builder(builder: widget.view),
    );
  }
}
