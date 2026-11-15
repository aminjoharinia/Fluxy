part of '../rx_types.dart';

/// Create a list similar to `List<T>`
class RxList<E> extends GetListenable<List<E>>
    with ListMixin<E>, RxObjectMixin<List<E>> {
  /// Growable empty list. Do not default to `const []` — that is an
  /// unmodifiable `List<Never>` and `addAll` then throws at runtime.
  RxList([List<E>? initial]) : super(initial ?? <E>[]);

  factory RxList.filled(int length, E fill, {bool growable = false}) {
    return RxList(List.filled(length, fill, growable: growable));
  }

  factory RxList.empty({bool growable = false}) {
    return RxList(List.empty(growable: growable));
  }

  /// Creates a list containing all [elements].
  factory RxList.from(Iterable elements, {bool growable = true}) {
    return RxList(List.from(elements, growable: growable));
  }

  /// Creates a list from [elements].
  factory RxList.of(Iterable<E> elements, {bool growable = true}) {
    return RxList(List.of(elements, growable: growable));
  }

  /// Generates a list of values.
  factory RxList.generate(int length, E Function(int index) generator,
      {bool growable = true}) {
    return RxList(List.generate(length, generator, growable: growable));
  }

  /// Creates an unmodifiable list containing all [elements].
  factory RxList.unmodifiable(Iterable elements) {
    return RxList(List.unmodifiable(elements));
  }

  @override
  Iterator<E> get iterator => value.iterator;

  @override
  void operator []=(int index, E val) {
    peek[index] = val;
    refresh();
  }

  /// Special override to push() element(s) in a reactive way
  /// inside the List,
  @override
  RxList<E> operator +(Iterable<E> val) {
    addAll(val);
    // refresh();
    return this;
  }

  @override
  E operator [](int index) {
    return value[index];
  }

  @override
  void add(E element) {
    peek.add(element);
    refresh();
  }

  /// A copy when [iterable] is this list (or its backing list), so
  /// `list.addAll(list)` doesn't modify the list while iterating it.
  Iterable<E> _snapshot(Iterable<E> iterable) =>
      identical(iterable, this) || identical(iterable, peek)
          ? iterable.toList(growable: false)
          : iterable;

  @override
  void addAll(Iterable<E> iterable) {
    peek.addAll(_snapshot(iterable));
    refresh();
  }

  @override
  bool remove(Object? element) {
    final removed = peek.remove(element);
    refresh();
    return removed;
  }

  @override
  void removeWhere(bool Function(E element) test) {
    peek.removeWhere(test);
    refresh();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    peek.retainWhere(test);
    refresh();
  }

  // The methods below would otherwise come from ListMixin, which works
  // through `[]=` and `length=` and so notifies several times per call.
  // Each one here changes the backing list directly and notifies once.

  @override
  void insert(int index, E element) {
    peek.insert(index, element);
    refresh();
  }

  @override
  E removeAt(int index) {
    final removed = peek.removeAt(index);
    refresh();
    return removed;
  }

  @override
  E removeLast() {
    final removed = peek.removeLast();
    refresh();
    return removed;
  }

  @override
  void removeRange(int start, int end) {
    peek.removeRange(start, end);
    refresh();
  }

  @override
  void setAll(int index, Iterable<E> iterable) {
    peek.setAll(index, _snapshot(iterable));
    refresh();
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    peek.setRange(start, end, _snapshot(iterable), skipCount);
    refresh();
  }

  @override
  void replaceRange(int start, int end, Iterable<E> newContents) {
    peek.replaceRange(start, end, _snapshot(newContents));
    refresh();
  }

  @override
  void fillRange(int start, int end, [E? fill]) {
    peek.fillRange(start, end, fill);
    refresh();
  }

  @override
  void clear() {
    peek.clear();
    refresh();
  }

  @override
  void shuffle([Random? random]) {
    peek.shuffle(random);
    refresh();
  }

  @override
  int get length => value.length;

  // @override
  // @protected
  // List<E> get value {
  //   RxInterface.proxy?.addListener(subject);
  //   return subject.value;
  // }

  @override
  set length(int newLength) {
    peek.length = newLength;
    refresh();
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    peek.insertAll(index, _snapshot(iterable));
    refresh();
  }

  @override
  Iterable<E> get reversed => value.reversed;

  // @override
  // set value(List<E> val) {
  //   value = val;
  //   refresh();
  // }

  @override
  Iterable<E> where(bool Function(E) test) {
    return value.where(test);
  }

  @override
  Iterable<T> whereType<T>() {
    return value.whereType<T>();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    peek.sort(compare);
    refresh();
  }
}

extension ListExtension<E> on List<E> {
  RxList<E> get obs => RxList<E>(this);

  /// Add [item] to [List<E>] only if [item] is not null.
  void addNonNull(E item) {
    if (item != null) add(item);
  }

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
  void assign(E item) {
    // if (this is RxList) {
    //   (this as RxList)._value;
    // }

    if (this is RxList) {
      (this as RxList<E>).peek.clear();
    } else {
      clear();
    }
    add(item);
  }

  /// Replaces all existing items of this list with [items]
  /// For an [RxList] this notifies once.
  void assignAll(Iterable<E> items) {
    final copy = items.toList(growable: false);
    if (this is RxList) {
      (this as RxList<E>).peek.clear();
    } else {
      clear();
    }
    addAll(copy);
  }
}
