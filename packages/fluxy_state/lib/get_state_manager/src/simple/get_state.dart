// ignore_for_file: overridden_fields

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'list_notifier.dart';

typedef InitBuilder<T> = T Function();

typedef FluxyControllerBuilder<T extends FluxyLifeCycleMixin> = Widget Function(
    T controller);

extension WatchExt on BuildContext {
  T listen<T>() {
    return Bind.of(this, rebuild: true);
  }
}

extension ReadExt on BuildContext {
  T get<T>() {
    return Bind.of(this);
  }
}

// extension FilterExt on BuildContext {
//   T filter<T extends FluxyController>(Object Function(T value)? filter) {
//     return Bind.of(this, filter: filter, rebuild: true);
//   }
// }

class FluxyBuilder<T extends FluxyController> extends StatelessWidget {
  final FluxyControllerBuilder<T> builder;
  final bool global;
  final Object? id;
  final String? tag;
  final bool autoRemove;
  final bool assignId;
  final Object Function(T value)? filter;
  final void Function(BindElement<T> state)? initState,
      dispose,
      didChangeDependencies;
  final void Function(Binder<T> oldWidget, BindElement<T> state)?
      didUpdateWidget;
  final T? init;

  const FluxyBuilder({
    super.key,
    this.init,
    this.global = true,
    required this.builder,
    this.autoRemove = true,
    this.assignId = false,
    this.initState,
    this.filter,
    this.tag,
    this.dispose,
    this.id,
    this.didChangeDependencies,
    this.didUpdateWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Binder(
      init: init == null ? null : () => init!,
      global: global,
      autoRemove: autoRemove,
      assignId: assignId,
      initState: initState,
      filter: filter,
      tag: tag,
      dispose: dispose,
      id: id,
      lazy: false,
      didChangeDependencies: didChangeDependencies,
      didUpdateWidget: didUpdateWidget,
      child: Builder(builder: (context) {
        final controller = Bind.of<T>(context, rebuild: true);
        return builder(controller);
      }),
    );
    // return widget.builder(controller!);
  }
}

abstract class Bind<T> extends StatelessWidget {
  const Bind({
    super.key,
    required this.child,
    this.init,
    this.global = true,
    this.autoRemove = true,
    this.assignId = false,
    this.initState,
    this.filter,
    this.tag,
    this.dispose,
    this.id,
    this.didChangeDependencies,
    this.didUpdateWidget,
  });

  final InitBuilder<T>? init;

  final bool global;
  final Object? id;
  final String? tag;
  final bool autoRemove;
  final bool assignId;
  final Object Function(T value)? filter;
  final void Function(BindElement<T> state)? initState,
      dispose,
      didChangeDependencies;
  final void Function(Binder<T> oldWidget, BindElement<T> state)?
      didUpdateWidget;

  final Widget? child;

  static Bind put<S>(
    S dependency, {
    String? tag,
    bool permanent = false,
  }) {
    Fluxy.put<S>(dependency, tag: tag, permanent: permanent);
    return _FactoryBind<S>(
      autoRemove: !permanent,
      assignId: true,
      tag: tag,
    );
  }

  static Bind lazyPut<S>(
    InstanceBuilderCallback<S> builder, {
    String? tag,
    VoidCallback? onClose,
  }) {
    Fluxy.lazyPut<S>(builder, tag: tag);
    return _FactoryBind<S>(
      tag: tag,
      dispose: (_) {
        onClose?.call();
      },
    );
  }

  static Bind create<S>(InstanceCreateBuilderCallback<S> builder,
      {String? tag, bool permanent = true}) {
    return _FactoryBind<S>(
      create: builder,
      tag: tag,
      global: false,
    );
  }

  static Bind spawn<S>(InstanceBuilderCallback<S> builder,
      {String? tag, bool permanent = true}) {
    Fluxy.spawn<S>(builder, tag: tag, permanent: permanent);
    return _FactoryBind<S>(
      tag: tag,
      global: false,
      autoRemove: !permanent,
    );
  }

  static S find<S>({String? tag}) => Fluxy.find<S>(tag: tag);

  static Future<bool> delete<S>({String? tag, bool force = false}) async =>
      Fluxy.delete<S>(tag: tag, force: force);

  static Future<void> deleteAll({bool force = false}) async =>
      Fluxy.deleteAll(force: force);

  static void reloadAll({bool force = false}) => Fluxy.reloadAll(force: force);

  static void reload<S>({String? tag, bool force = false}) =>
      Fluxy.reload<S>(tag: tag, force: force);

  static bool isRegistered<S>({String? tag}) => Fluxy.isRegistered<S>(tag: tag);

  static bool isPrepared<S>({String? tag}) => Fluxy.isPrepared<S>(tag: tag);

  static void replace<P>(P child, {String? tag}) =>
      Fluxy.replace<P>(child, tag: tag);

  static void lazyReplace<P>(InstanceBuilderCallback<P> builder,
          {String? tag}) =>
      Fluxy.lazyReplace<P>(builder, tag: tag);

  factory Bind.builder({
    Widget? child,
    InitBuilder<T>? init,
    InstanceCreateBuilderCallback<T>? create,
    bool global = true,
    bool autoRemove = true,
    bool assignId = false,
    Object Function(T value)? filter,
    String? tag,
    Object? id,
    void Function(BindElement<T> state)? initState,
    void Function(BindElement<T> state)? dispose,
    void Function(BindElement<T> state)? didChangeDependencies,
    void Function(Binder<T> oldWidget, BindElement<T> state)? didUpdateWidget,
  }) =>
      _FactoryBind<T>(
        // key: key,
        init: init,
        create: create,
        global: global,
        autoRemove: autoRemove,
        assignId: assignId,
        initState: initState,
        filter: filter,
        tag: tag,
        dispose: dispose,
        id: id,
        didChangeDependencies: didChangeDependencies,
        didUpdateWidget: didUpdateWidget,
        child: child,
      );

  static T of<T>(
    BuildContext context, {
    bool rebuild = false,
    // Object Function(T value)? filter,
  }) {
    final inheritedElement =
        context.getElementForInheritedWidgetOfExactType<Binder<T>>()
            as BindElement<T>?;

    if (inheritedElement == null) {
      throw BindError(controller: '$T', tag: null);
    }

    if (rebuild) {
      // var newFilter = filter?.call(inheritedElement.controller!);
      // if (newFilter != null) {
      //  context.dependOnInheritedElement(inheritedElement, aspect: newFilter);
      // } else {
      context.dependOnInheritedElement(inheritedElement);
      // }
    }

    final controller = inheritedElement.controller;

    return controller;
  }

  @factory
  Bind<T> _copyWithChild(Widget child);
}

class _FactoryBind<T> extends Bind<T> {
  @override
  final InitBuilder<T>? init;

  final InstanceCreateBuilderCallback<T>? create;

  @override
  final bool global;
  @override
  final Object? id;
  @override
  final String? tag;
  @override
  final bool autoRemove;
  @override
  final bool assignId;
  @override
  final Object Function(T value)? filter;

  @override
  final void Function(BindElement<T> state)? initState,
      dispose,
      didChangeDependencies;
  @override
  final void Function(Binder<T> oldWidget, BindElement<T> state)?
      didUpdateWidget;

  @override
  final Widget? child;

  const _FactoryBind({
    super.key,
    this.child,
    this.init,
    this.create,
    this.global = true,
    this.autoRemove = true,
    this.assignId = false,
    this.initState,
    this.filter,
    this.tag,
    this.dispose,
    this.id,
    this.didChangeDependencies,
    this.didUpdateWidget,
  }) : super(child: child);

  @override
  Bind<T> _copyWithChild(Widget child) {
    return Bind<T>.builder(
      init: init,
      create: create,
      global: global,
      autoRemove: autoRemove,
      assignId: assignId,
      initState: initState,
      filter: filter,
      tag: tag,
      dispose: dispose,
      id: id,
      didChangeDependencies: didChangeDependencies,
      didUpdateWidget: didUpdateWidget,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Binder<T>(
      create: create,
      global: global,
      autoRemove: autoRemove,
      assignId: assignId,
      initState: initState,
      filter: filter,
      tag: tag,
      dispose: dispose,
      id: id,
      didChangeDependencies: didChangeDependencies,
      didUpdateWidget: didUpdateWidget,
      child: child!,
    );
  }
}

class Binds extends StatelessWidget {
  final List<Bind<dynamic>> binds;
  final Widget child;

  Binds({
    super.key,
    required this.binds,
    required this.child,
  }) : assert(binds.isNotEmpty);

  @override
  Widget build(BuildContext context) =>
      binds.reversed.fold(child, (widget, e) => e._copyWithChild(widget));
}

class Binder<T> extends InheritedWidget {
  /// Create an inherited widget that updates its dependents when [controller]
  /// sends notifications.
  ///
  /// The [child] argument is required
  const Binder({
    super.key,
    required super.child,
    this.init,
    this.global = true,
    this.autoRemove = true,
    this.assignId = false,
    this.lazy = true,
    this.initState,
    this.filter,
    this.tag,
    this.dispose,
    this.id,
    this.didChangeDependencies,
    this.didUpdateWidget,
    this.create,
  });

  final InitBuilder<T>? init;
  final InstanceCreateBuilderCallback? create;
  final bool global;
  final Object? id;
  final String? tag;
  final bool lazy;
  final bool autoRemove;
  final bool assignId;
  final Object Function(T value)? filter;
  final void Function(BindElement<T> state)? initState,
      dispose,
      didChangeDependencies;
  final void Function(Binder<T> oldWidget, BindElement<T> state)?
      didUpdateWidget;

  @override
  bool updateShouldNotify(Binder<T> oldWidget) {
    return oldWidget.id != id ||
        oldWidget.global != global ||
        oldWidget.autoRemove != autoRemove ||
        oldWidget.assignId != assignId;
  }

  @override
  InheritedElement createElement() => BindElement<T>(this);
}

/// The BindElement is responsible for injecting dependencies into the widget
/// tree so that they can be observed
class BindElement<T> extends InheritedElement {
  BindElement(Binder<T> super.widget) {
    initState();
  }

  final disposers = <Disposer>[];

  InitBuilder<T>? _controllerBuilder;

  T? _controller;

  T get controller {
    if (_controller == null) {
      _controller = _controllerBuilder?.call();
      _subscribeToController();
      if (_controller == null) {
        throw BindError(controller: T, tag: widget.tag);
      }
      return _controller!;
    } else {
      return _controller!;
    }
  }

  bool? _needStart = false;
  VoidCallback? _remove;
  Object? _filter;

  /// The registration this binder owns (created it, claimed a `lazyPut` /
  /// `Bind.put` one, or shares one another widget created). It is deleted
  /// when its last owner goes.
  DependencyEntry<dynamic>? _owned;

  void initState() {
    widget.initState?.call(this);

    if (widget.global) {
      final key = FluxyScope.keyOf(T, widget.tag);
      var entry = FluxyScope.lookup(key);
      if (entry == null) {
        T build() => (widget.create?.call(this) ?? widget.init?.call()) as T;
        if (widget.lazy) {
          Fluxy.lazyPut<T>(build, tag: widget.tag);
        } else {
          Fluxy.put<T>(build(), tag: widget.tag);
        }
        entry = FluxyScope.lookup(key)!;
        _owned = entry..addOwner();
      } else if (widget.assignId ||
          entry.widgetOwned ||
          (entry.kind == DependencyKind.lazy && !entry.isCreated)) {
        _owned = entry..addOwner();
      }
      final found = entry;
      _controllerBuilder = () => found.resolve() as T;
    } else {
      // A local controller: not registered; started on first use and
      // closed with this binder.
      _controllerBuilder =
          (widget.create != null ? () => widget.create!.call(this) : null) ??
              widget.init;
      _needStart = true;
    }
  }

  void _subscribeToController() {
    if (widget.filter != null) {
      _filter = widget.filter!(_controller as T);
    }
    final filter = _filter != null ? _filterUpdate : getUpdate;
    final localController = _controller;

    if (_needStart == true && localController is FluxyLifeCycleMixin) {
      localController.onStart();
      _needStart = false;
    }

    if (localController is FluxyController) {
      _remove?.call();
      _remove = (widget.id == null)
          ? localController.addListener(filter)
          : localController.addListenerId(widget.id, filter);
    } else if (localController is Listenable) {
      _remove?.call();
      localController.addListener(filter);
      _remove = () => localController.removeListener(filter);
    } else if (localController is StreamController) {
      _remove?.call();
      final stream = localController.stream.listen((_) => filter());
      _remove = () => stream.cancel();
    }
  }

  void _filterUpdate() {
    var newFilter = widget.filter!(_controller as T);
    if (newFilter != _filter) {
      _filter = newFilter;
      getUpdate();
    }
  }

  void dispose() {
    widget.dispose?.call(this);
    final owned = _owned;
    if (owned != null &&
        owned.removeOwner() &&
        widget.autoRemove &&
        identical(owned.scope.local(owned.key), owned)) {
      owned.delete();
    } else if (!widget.global && widget.autoRemove) {
      final local = _controller;
      if (local is FluxyLifeCycleMixin) local.onDelete();
    }
    _owned = null;

    for (final disposer in disposers) {
      disposer();
    }

    disposers.clear();

    _remove?.call();
    _controller = null;
    _remove = null;
    _filter = null;
    _needStart = null;
    _controllerBuilder = null;
  }

  @override
  Binder<T> get widget => super.widget as Binder<T>;

  var _dirty = false;

  @override
  void update(Binder<T> newWidget) {
    final oldNotifier = widget.id;
    final newNotifier = newWidget.id;
    widget.didUpdateWidget?.call(widget, this);
    super.update(newWidget);
    // Re-subscribe under the new id once the controller exists (global or
    // not). Before, only `global: false` binders re-subscribed, so a
    // FluxyBuilder whose id changed kept listening to the old id.
    if (oldNotifier != newNotifier && _controller != null) {
      _subscribeToController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.didChangeDependencies?.call(this);
  }

  @override
  Widget build() {
    if (_dirty) {
      notifyClients(widget);
    }
    // return Notifier.instance.notifyAppend(
    //   NotifyData(
    //       disposers: disposers, updater: getUpdate, throwException: false),
    return super.build();
    //);
  }

  void getUpdate() {
    _dirty = true;
    markNeedsBuild();
  }

  @override
  void notifyClients(Binder<T> oldWidget) {
    super.notifyClients(oldWidget);
    _dirty = false;
  }

  @override
  void unmount() {
    dispose();
    super.unmount();
  }
}

class BindError<T> extends Error {
  /// The type of the class the user tried to retrieve
  final T controller;
  final String? tag;

  /// Creates a [BindError]
  BindError({required this.controller, required this.tag});

  @override
  String toString() {
    if (controller == 'dynamic') {
      return '''Error: please specify type [<T>] when calling context.listen<T>() or context.find<T>() method.''';
    }

    return '''Error: No Bind<$controller>  ancestor found. To fix this, please add a Bind<$controller> widget ancestor to the current context.
      ''';
  }
}

/// [Binding] should be extended.
/// When using `FluxyApp`, all `FluxyPage`s and navigation
/// methods (like Fluxy.to()) have a `binding` property that takes an
/// instance of Bindings to manage the
/// dependencies() (via Fluxy.put()) for the Route you are opening.
// ignore: one_member_abstracts
abstract class Binding extends BindingsInterface<List<Bind>> {}
