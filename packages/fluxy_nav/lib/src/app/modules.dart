import 'package:material_ui/material_ui.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';

class Dependencies {
  void lazyPut<S>(InstanceBuilderCallback<S> builder,
      {String? tag, bool fenix = false}) {
    Fluxy.lazyPut<S>(builder, tag: tag, fenix: fenix);
  }

  S call<S>() {
    return find<S>();
  }

  void spawn<S>(InstanceBuilderCallback<S> builder,
          {String? tag, bool permanent = true}) =>
      Fluxy.spawn<S>(builder, tag: tag, permanent: permanent);

  S find<S>({String? tag}) => Fluxy.find<S>(tag: tag);

  S put<S>(S dependency,
          {String? tag,
          bool permanent = false,
          InstanceBuilderCallback<S>? builder}) =>
      Fluxy.put<S>(dependency, tag: tag, permanent: permanent);

  Future<bool> delete<S>({String? tag, bool force = false}) async =>
      Fluxy.delete<S>(tag: tag, force: force);

  Future<void> deleteAll({bool force = false}) async =>
      Fluxy.deleteAll(force: force);

  void reloadAll({bool force = false}) => Fluxy.reloadAll(force: force);

  void reload<S>({String? tag, Object? key, bool force = false}) =>
      Fluxy.reload<S>(tag: tag, key: key, force: force);

  bool isRegistered<S>({String? tag}) => Fluxy.isRegistered<S>(tag: tag);

  bool isPrepared<S>({String? tag}) => Fluxy.isPrepared<S>(tag: tag);

  void replace<P>(P child, {String? tag}) {
    final info = Fluxy.getInstanceInfo<P>(tag: tag);
    final permanent = (info.isPermanent ?? false);
    delete<P>(tag: tag, force: permanent);
    put(child, tag: tag, permanent: permanent);
  }

  void lazyReplace<P>(InstanceBuilderCallback<P> builder,
      {String? tag, bool? fenix}) {
    final info = Fluxy.getInstanceInfo<P>(tag: tag);
    final permanent = (info.isPermanent ?? false);
    delete<P>(tag: tag, force: permanent);
    lazyPut(builder, tag: tag, fenix: fenix ?? permanent);
  }
}

abstract class Module extends StatefulWidget {
  const Module({super.key});

  Widget view(BuildContext context);

  void dependencies(Dependencies i);

  @override
  ModuleState createState() => ModuleState();
}

class ModuleState extends State<Module> {
  @override
  void initState() {
    RouterReportManager.instance.reportCurrentRoute(this);
    widget.dependencies(Dependencies());
    super.initState();
  }

  @override
  void dispose() {
    RouterReportManager.instance.reportRouteDispose(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.view(context);
  }
}
