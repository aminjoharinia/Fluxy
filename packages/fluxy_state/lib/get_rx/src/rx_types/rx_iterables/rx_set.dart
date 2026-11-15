part of '../rx_types.dart';

class RxSet<E> extends GetListenable<Set<E>>
    with SetMixin<E>, RxObjectMixin<Set<E>> {
  RxSet([Set<E>? initial]) : super(initial ?? <E>{});

  /// Special override to push() element(s) in a reactive way
  /// inside the List,
  RxSet<E> operator +(Set<E> val) {
    addAll(val);
    //refresh();
    return this;
  }

  void update(void Function(Iterable<E>? value) fn) {
    fn(value);
    refresh();
  }

  // @override
  // @protected
  // Set<E> get value {
  //   return subject.value;
  //   // RxInterface.proxy?.addListener(subject);
  //   // return _value;
  // }

  // @override
  // @protected
  // set value(Set<E> val) {
  //   if (value == val) return;
  //   value = val;
  //   refresh();
  // }

  @override
  bool add(E value) {
    final hasAdded = peek.add(value);
    if (hasAdded) {
      refresh();
    }
    return hasAdded;
  }

  @override
  bool contains(Object? element) {
    return value.contains(element);
  }

  @override
  Iterator<E> get iterator => value.iterator;

  @override
  int get length => value.length;

  @override
  E? lookup(Object? element) {
    return value.lookup(element);
  }

  @override
  bool remove(Object? value) {
    final hasRemoved = peek.remove(value);
    if (hasRemoved) {
      refresh();
    }
    return hasRemoved;
  }

  @override
  Set<E> toSet() {
    return value.toSet();
  }

  @override
  void addAll(Iterable<E> elements) {
    final items = identical(elements, this) || identical(elements, peek)
        ? elements.toList(growable: false)
        : elements;
    peek.addAll(items);
    refresh();
  }

  @override
  void clear() {
    peek.clear();
    refresh();
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    peek.removeAll(elements.toList(growable: false));
    refresh();
  }

  @override
  void retainAll(Iterable<Object?> elements) {
    peek.retainAll(elements.toList(growable: false));
    refresh();
  }

  @override
  void removeWhere(bool Function(E) test) {
    peek.removeWhere(test);
    refresh();
  }

  @override
  void retainWhere(bool Function(E) test) {
    peek.retainWhere(test);
    refresh();
  }
}

extension SetExtension<E> on Set<E> {
  RxSet<E> get obs {
    return RxSet<E>(<E>{})..addAll(this);
  }

  // /// Add [item] to [List<E>] only if [item] is not null.
  // void addNonNull(E item) {
  //   if (item != null) add(item);
  // }

  // /// Add [Iterable<E>] to [List<E>] only if [Iterable<E>] is not null.
  // void addAllNonNull(Iterable<E> item) {
  //   if (item != null) addAll(item);
  // }

  /// Add [item] to [List<E>] only if [condition] is true.
  void addIf(dynamic condition, E item) {
    if (condition is Condition) condition = condition();
    if (condition is bool && condition) add(item);
  }

  /// Adds [Iterable<E>] to [List<E>] only if [condition] is true.
  void addAllIf(dynamic condition, Iterable<E> items) {
    if (condition is Condition) condition = condition();
    if (condition is bool && condition) addAll(items);
  }

  /// Replaces all existing items of this list with [item]
  /// For an [RxSet] this notifies once.
  void assign(E item) => assignAll([item]);

  /// Replaces all existing items of this set with [items].
  /// For an [RxSet] this notifies once.
  void assignAll(Iterable<E> items) {
    final next = items.toSet();
    if (this is RxSet<E>) {
      final rx = this as RxSet<E>;
      rx.peek
        ..clear()
        ..addAll(next);
      // ignore: invalid_use_of_protected_member
      rx.refresh();
      return;
    }
    clear();
    addAll(next);
  }
}
