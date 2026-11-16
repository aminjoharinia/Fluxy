import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:fluxy_core/fluxy_core.dart';
import '../../../get_instance/src/extension_instance.dart';
import '../../../get_instance/src/lifecycle.dart';
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
  bool? _isCreator = false;

  @override
  void initState() {
    // var isPrepared = Fluxy.isPrepared<T>(tag: widget.tag);
    final isRegistered = Fluxy.isRegistered<T>(tag: widget.tag);

    if (widget.global) {
      if (isRegistered) {
        _isCreator = Fluxy.isPrepared<T>(tag: widget.tag);
        controller = Fluxy.find<T>(tag: widget.tag);
      } else {
        controller = widget.init;
        _isCreator = true;
        Fluxy.put<T>(controller!, tag: widget.tag);
      }
    } else {
      controller = widget.init;
      _isCreator = true;
      controller?.onStart();
    }
    widget.initState?.call(this);
    if (widget.global && Fluxy.smartManagement == SmartManagement.onlyBuilder) {
      controller?.onStart();
    }

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
    if (_isCreator! || widget.assignId) {
      if (widget.autoRemove && Fluxy.isRegistered<T>(tag: widget.tag)) {
        Fluxy.delete<T>(tag: widget.tag);
      }
    }

    subscriptions.dispose();
    for (final disposer in disposers) {
      disposer();
    }

    disposers.clear();

    controller = null;
    _isCreator = null;
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
