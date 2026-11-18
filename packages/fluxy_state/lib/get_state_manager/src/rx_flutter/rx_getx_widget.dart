import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:fluxy_core/fluxy_core.dart';
import '../../../src/di/facade.dart';
import '../../../src/di/scope.dart';
import '../../../src/di/lifecycle.dart';
import '../simple/list_notifier.dart';

typedef FluxyXControllerBuilder<T extends FluxyLifeCycleMixin> = Widget Function(
    T controller);

class FluxyX<T extends FluxyLifeCycleMixin> extends StatefulWidget {
  final FluxyXControllerBuilder<T> builder;
  final bool global;
  final bool autoRemove;
  final bool assignId;
  final void Function(FluxyXState<T> state)? initState,
      dispose,
      didChangeDependencies;
  final void Function(FluxyX oldWidget, FluxyXState<T> state)? didUpdateWidget;
  final T? init;
  final String? tag;

  const FluxyX({
    super.key,
    this.tag,
    required this.builder,
    this.global = true,
    this.autoRemove = true,
    this.initState,
    this.assignId = false,
    //  this.stream,
    this.dispose,
    this.didChangeDependencies,
    this.didUpdateWidget,
    this.init,
    // this.streamController
  });

  @override
  StatefulElement createElement() => StatefulElement(this);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        DiagnosticsProperty<T>('controller', init),
      )
      ..add(DiagnosticsProperty<String>('tag', tag))
      ..add(
          ObjectFlagProperty<FluxyXControllerBuilder<T>>.has('builder', builder));
  }

  @override
  FluxyXState<T> createState() => FluxyXState<T>();
}

class FluxyXState<T extends FluxyLifeCycleMixin> extends State<FluxyX<T>> {
  T? controller;

  /// The registration this widget owns (created, or shares with other
  /// widgets); deleted when its last owner goes.
  DependencyEntry<dynamic>? _owned;

  @override
  void initState() {
    if (widget.global) {
      final key = FluxyScope.keyOf(T, widget.tag);
      var entry = FluxyScope.lookup(key);
      if (entry == null) {
        Fluxy.put<T>(widget.init!, tag: widget.tag);
        entry = FluxyScope.lookup(key)!;
        _owned = entry..addOwner();
      } else if (widget.assignId ||
          entry.widgetOwned ||
          (entry.kind == DependencyKind.lazy && !entry.isCreated)) {
        _owned = entry..addOwner();
      }
      controller = entry.resolve() as T;
    } else {
      controller = widget.init;
      controller?.onStart();
    }
    widget.initState?.call(this);

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.didChangeDependencies != null) {
      widget.didChangeDependencies!(this);
    }
  }

  @override
  void didUpdateWidget(FluxyX oldWidget) {
    super.didUpdateWidget(oldWidget as FluxyX<T>);
    widget.didUpdateWidget?.call(oldWidget, this);
  }

  @override
  void dispose() {
    if (widget.dispose != null) widget.dispose!(this);
    final owned = _owned;
    if (owned != null &&
        owned.removeOwner() &&
        widget.autoRemove &&
        identical(owned.scope.local(owned.key), owned)) {
      owned.delete();
    } else if (!widget.global && widget.autoRemove) {
      controller?.onDelete();
    }
    _owned = null;

    subscriptions.dispose();
    for (final disposer in disposers) {
      disposer();
    }

    disposers.clear();

    controller = null;
    super.dispose();
  }

  void _update() {
    if (mounted) {
      setState(() {});
    }
  }

  final disposers = <Disposer>[];
  late final subscriptions = TrackedSources()..listen(_update);
  late final _notifyData = NotifyData(
      disposers: disposers, subscriptions: subscriptions, updater: _update);

  @override
  Widget build(BuildContext context) =>
      Notifier.instance.append(_notifyData, () => widget.builder(controller!));

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<T>('controller', controller));
  }
}
