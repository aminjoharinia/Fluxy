part of '../rx_types.dart';

/// global object that registers against `FluxyX` and `Obx`, and allows the
/// reactivity
/// of those `Widgets` and Rx values.

mixin RxObjectMixin<T> on FluxyListenable<T> {
  //late T _value;

  /// Makes a direct update of [value] adding it to the Stream
  /// useful when you make use of Rx for custom Types to refresh your UI.
  ///
  /// Sample:
  /// ```
  ///  class Person {
  ///     String name, last;
  ///     int age;
  ///     Person({this.name, this.last, this.age});
  ///     @override
  ///     String toString() => '$name $last, $age years old';
  ///  }
  ///
  /// final person = Person(name: 'John', last: 'Doe', age: 18).obs;
  /// person.value.name = 'Roi';
  /// person.refresh();
  /// print( person );
  /// ```
  // void refresh() {
  //   subject.add(value);
  // }

  /// updates the value to `null` and adds it to the Stream.
  /// Even with null-safety coming, is still an important feature to support, as
  /// `call()` doesn't accept `null` values. For instance,
  /// `InputDecoration.errorText` has to be null to not show the "error state".
  ///
  /// Sample:
  /// ```
  /// final inputError = ''.obs..nil();
  /// print('${inputError.runtimeType}: $inputError'); // outputs > RxString: null
  /// ```
  // void nil() {
  //   subject.add(_value = null);
  // }

  // `call` (`rx()` / `rx(v)` / `rxn(null)`) is defined on FluxyListenable.
  // It lets an Rx be passed where a `ValueChanged` is expected:
  // `TextField(onChanged: myText)`.

  /// Same as `toString()` but using a getter.
  String get string => value.toString();

  @override
  String toString() => value.toString();

  /// Returns the json representation of `value`.
  dynamic toJson() => value;

  /// This equality override works for _RxImpl instances and the internal
  /// values.
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object o) {
    // Todo, find a common implementation for the hashCode of different Types.
    if (o is T) return value == o;
    if (o is RxObjectMixin<T>) return value == o.value;
    return false;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => value.hashCode;

  /// True when this Rx was closed, so a write must be ignored. In debug
  /// builds it throws instead (release builds still ignore the write): a
  /// write after `close()` is usually a callback (a Future, a stream, a
  /// timer) that outlived the widget or controller that closed this Rx, and
  /// silently dropping it hid the bug.
  bool _writeAfterClose(String what) {
    if (!isDisposed) return false;
    assert(() {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('A $runtimeType was $what after close().'),
        ErrorDescription(
            'Writes to a closed Rx are ignored in release builds and throw in '
            'debug builds, so a late write is found.'),
        ErrorHint(
            'Usually a callback (a Future, a stream, a timer) outlived the '
            'widget or controller that closed this Rx. Cancel it in '
            'onClose / dispose, or check `isDisposed` before writing.'),
      ]);
    }());
    return true;
  }

  /// Updates the [value] and adds it to the stream, updating the observer
  /// Widget, only if it's different from the previous value.
  @override
  set value(T val) {
    if (_writeAfterClose('given a value')) return;
    final current = peek;
    if (current == val) {
      assert(() {
        if (identical(current, val) && (val is Map || val is Iterable)) {
          debugPrint('[Fluxy] An Rx was given the same ${val.runtimeType} '
              'object it already holds, so it does not notify. If that '
              'object was edited in place, write a copy instead (mapWith / '
              'listWith / setIn ...).');
        }
        return true;
      }());
      return;
    }
    // Compared once: the value's == can be costly (a model with lists).
    // An equal value never notifies, the first write included.
    setValueUnchecked(val);
  }

  /// Returns a [StreamSubscription] similar to [listen], but with the
  /// added benefit that it primes the stream with the current [value], rather
  /// than waiting for the next [value]. This should not be called in [onInit]
  /// or anywhere else during the build process.
  ///
  /// Only this subscription gets the current value; other listeners of this
  /// Rx do not see it again. (Before, the current value was added to the
  /// shared stream, so every `ever` / `listen` fired once more.)
  StreamSubscription<T> listenAndPump(void Function(T event) onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final current = peek;
    return Stream<T>.multi((controller) {
      controller.add(current);
      final sub = stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    }).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError ?? false,
    );
  }

  /// Binds an existing `Stream<T>` to this `Rx<T>` to keep the values in sync.
  /// You can bind multiple sources to update the value.
  ///
  /// The subscription is cancelled when this Rx is closed, when [stream] is
  /// done, or when you cancel the returned subscription. If it is bound while
  /// an observer widget (`FluxyX` or `Obx`) builds, it is also cancelled when
  /// that widget is unmounted. (Before, a binding made outside a build, for
  /// example in `onInit`, was never cancelled.)
  StreamSubscription<T> bindStream(Stream<T> stream) {
    late final StreamSubscription<T> sub;
    sub = stream.listen(
      (va) => value = va,
      onDone: () => _bindings?.remove(sub),
    );
    (_bindings ??= <StreamSubscription<T>>[]).add(sub);
    reportAdd(sub.cancel);
    return sub;
  }

  List<StreamSubscription<T>>? _bindings;

  @override
  void close() {
    final bindings = _bindings;
    _bindings = null;
    if (bindings != null) {
      for (final sub in bindings) {
        sub.cancel();
      }
    }
    super.close();
  }
}

/// Base Rx class that manages all the stream logic for any Type.
abstract class _RxImpl<T> extends FluxyListenable<T> with RxObjectMixin<T> {
  _RxImpl(super.initial);

  void addError(Object error, [StackTrace? stackTrace]) {
    subject.addError(error, stackTrace);
  }

  Stream<R> map<R>(R Function(T? data) mapper) => stream.map(mapper);

  /// Uses a callback to update [value] internally, similar to [refresh],
  /// but provides the current value as the argument.
  /// Makes sense for custom Rx types (like Models).
  ///
  /// Sample:
  /// ```
  ///  class Person {
  ///     String name, last;
  ///     int age;
  ///     Person({this.name, this.last, this.age});
  ///     @override
  ///     String toString() => '$name $last, $age years old';
  ///  }
  ///
  /// final person = Person(name: 'John', last: 'Doe', age: 18).obs;
  /// person.update((person) {
  ///   person.name = 'Roi';
  /// });
  /// print( person );
  /// ```
  ///
  /// If [fn] returns the same object it was given (it edited it in place),
  /// listeners are still notified.
  void update(T Function(T? val) fn) {
    if (_writeAfterClose('updated')) return;
    final current = peek;
    final next = fn(current);
    // Also on the first write (it used to need an earlier write first).
    if (identical(next, current)) {
      refresh();
    } else {
      value = next;
    }
  }

  /// Following certain practices on Rx data, we might want to react to certain
  /// listeners when a value has been provided, even if the value is the same.
  /// At the moment, we ignore part of the process if we `.call(value)` with
  /// the same value since it holds the value and there's no real
  /// need triggering the entire process for the same value inside, but
  /// there are other situations where we might be interested in
  /// triggering this.
  ///
  /// For example, supposed we have a `int seconds = 2` and we want to animate
  /// from invisible to visible a widget in two seconds:
  /// `RxEvent<int>.call(seconds);`
  /// then after a click happens, you want to call a `RxEvent<int>.call(seconds)`.
  /// By doing `call(seconds)`, if the value being held is the same,
  /// the listeners won't trigger, hence we need this new `trigger` function.
  /// This will refresh the listener of an AnimatedWidget and will keep
  /// the value if the Rx is kept in memory.
  /// Sample:
  /// ```
  /// Rx<Int> secondsRx = RxInt();
  /// secondsRx.listen((value) => print("$value seconds set"));
  ///
  /// secondsRx.call(2);      // This won't trigger any listener, since the value is the same
  /// secondsRx.trigger(2);   // This will trigger the listener independently from the value.
  /// ```
  ///
  void trigger(T v) {
    if (_writeAfterClose('triggered')) return;
    // Same value: the setter would not notify, so notify here. This reaches
    // every listener (Obx, FluxyBuilder, workers), not only the stream as it
    // used to.
    if (peek == v) {
      refresh();
    } else {
      value = v;
    }
  }
}

class RxBool extends Rx<bool> {
  RxBool(super.initial);
  @override
  String toString() {
    return value ? "true" : "false";
  }
}

class RxnBool extends Rx<bool?> {
  RxnBool([super.initial]);
  @override
  String toString() {
    return "$value";
  }
}

extension RxBoolExt on Rx<bool> {
  bool get isTrue => value;

  bool get isFalse => !isTrue;

  bool operator &(bool other) => other && value;

  bool operator |(bool other) => other || value;

  bool operator ^(bool other) => !other == value;

  /// Toggles the bool [value] between false and true.
  /// A shortcut for `flag.value = !flag.value;`
  void toggle() {
    call(!peek);
  }
}

extension RxnBoolExt on Rx<bool?> {
  bool? get isTrue => value;

  bool? get isFalse {
    if (value != null) return !isTrue!;
    return null;
  }

  bool? operator &(bool other) {
    if (value != null) {
      return other && value!;
    }
    return null;
  }

  bool? operator |(bool other) {
    if (value != null) {
      return other || value!;
    }
    return null;
  }

  bool? operator ^(bool other) => !other == value;

  /// Toggles the bool [value] between false and true.
  /// A shortcut for `flag.value = !flag.value;`
  void toggle() {
    final current = peek;
    if (current != null) {
      call(!current);
    }
  }
}

/// Foundation class used for custom `Types` outside the common native Dart
/// types.
/// For example, any custom "Model" class, like User().obs will use `Rx` as
/// wrapper.
class Rx<T> extends _RxImpl<T> {
  Rx(super.initial);

  @override
  dynamic toJson() {
    try {
      return (value as dynamic)?.toJson();
    } on Exception catch (_) {
      throw '$T has not method [toJson]';
    }
  }
}

class Rxn<T> extends Rx<T?> {
  Rxn([super.initial]);

  @override
  dynamic toJson() {
    try {
      return (value as dynamic)?.toJson();
    } on Exception catch (_) {
      throw '$T has not method [toJson]';
    }
  }
}

extension StringExtension on String {
  /// Returns a `RxString` with [this] `String` as initial value.
  RxString get obs => RxString(this);
}

extension IntExtension on int {
  /// Returns a `RxInt` with [this] `int` as initial value.
  RxInt get obs => RxInt(this);
}

extension DoubleExtension on double {
  /// Returns a `RxDouble` with [this] `double` as initial value.
  RxDouble get obs => RxDouble(this);
}

extension BoolExtension on bool {
  /// Returns a `RxBool` with [this] `bool` as initial value.
  RxBool get obs => RxBool(this);
}

extension RxT<T extends Object> on T {
  /// Returns a `Rx` instance with [this] `T` as initial value.
  Rx<T> get obs => Rx<T>(this);
}

/// This method will replace the old `.obs` method.
/// It's a breaking change, but it is essential to avoid conflicts with
/// the new dart 3 features. T will be inferred by contextual type inference
/// rather than the extension type.
extension RxTnew on Object {
  /// Returns a `Rx` instance with [this] `T` as initial value.
  Rx<T> obs<T>() => Rx<T>(this as T);
}
