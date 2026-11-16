import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'list_notifier.dart';

typedef ValueBuilderUpdateCallback<T> = void Function(T snapshot);
typedef ValueBuilderBuilder<T> = Widget Function(
    T snapshot, ValueBuilderUpdateCallback<T> updater);

/// Manages a local state like ObxValue, but uses a callback instead of
/// a Rx value.
///
/// Example:
/// ```
///  ValueBuilder<bool>(
///    initialValue: false,
///    builder: (value, update) => Switch(
///    value: value,
///    onChanged: (flag) {
///       update( flag );
///    },),
///    onUpdate: (value) => print("Value updated: $value"),
///  ),
///  ```
class ValueBuilder<T> extends StatefulWidget {
  final T initialValue;
  final ValueBuilderBuilder<T> builder;
  final void Function()? onDispose;
  final void Function(T)? onUpdate;

  const ValueBuilder({
    super.key,
    required this.initialValue,
    this.onDispose,
    this.onUpdate,
    required this.builder,
  });

  @override
  ValueBuilderState<T> createState() => ValueBuilderState<T>();
}

class ValueBuilderState<T> extends State<ValueBuilder<T>> {
  late T value;
  @override
  void initState() {
    value = widget.initialValue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => widget.builder(value, updater);

  void updater(T newValue) {
    if (widget.onUpdate != null) {
      widget.onUpdate!(newValue);
    }
    setState(() {
      value = newValue;
    });
  }

  @override
  void dispose() {
    super.dispose();
    widget.onDispose?.call();
    if (value is ChangeNotifier) {
      (value as ChangeNotifier?)?.dispose();
    } else if (value is StreamController) {
      (value as StreamController?)?.close();
    }
  }
}

class ObxElement = StatelessElement with StatelessObserverComponent;

// It's a experimental feature
class Observer extends ObxStatelessWidget {
  final WidgetBuilder builder;

  const Observer({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => builder(context);
}

/// A StatelessWidget than can listen reactive changes.
abstract class ObxStatelessWidget extends StatelessWidget {
  /// Initializes [key] for subclasses.
  const ObxStatelessWidget({super.key});
  @override
  StatelessElement createElement() => ObxElement(this);
}

/// a Component that can track changes in a reactive variable
mixin StatelessObserverComponent on StatelessElement {
  List<Disposer>? disposers = <Disposer>[];

  /// The Rx values read on the last build; values no longer read are
  /// unsubscribed after each build.
  /// Matched by position like a `Computed`'s sources: a rebuild that reads
  /// the same values in the same order costs no lookup and no allocation.
  late final TrackedSources subscriptions = TrackedSources()
    ..listen(getUpdate);

  /// Reused by every build.
  late final NotifyData _notifyData = NotifyData(
      disposers: disposers!, subscriptions: subscriptions, updater: getUpdate);

  bool _updateScheduled = false;

  void getUpdate() {
    if (disposers == null || _updateScheduled) return;
    // Outside the build phase (a tap, a timer, a stream, an animation tick)
    // mark it dirty right away: markNeedsBuild already coalesces and
    // ignores an inactive element. It used to schedule a microtask (and a
    // closure) per element on every change.
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      if (mounted) markNeedsBuild();
      return;
    }
    // During a build (an Rx written while another widget builds), marking
    // now could assert: one microtask per element however many Rx values
    // change before it runs.
    _updateScheduled = true;
    // Checked again when the microtask runs: the element may have been
    // unmounted in between, and markNeedsBuild on a defunct element asserts.
    scheduleMicrotask(() {
      _updateScheduled = false;
      if (disposers != null && mounted) markNeedsBuild();
    });
  }

  @override
  Widget build() {
    return Notifier.instance.append(_notifyData, super.build);
  }

  @override
  void unmount() {
    super.unmount();
    subscriptions.dispose();
    for (final disposer in disposers!) {
      disposer();
    }
    disposers!.clear();
    disposers = null;
  }
}
