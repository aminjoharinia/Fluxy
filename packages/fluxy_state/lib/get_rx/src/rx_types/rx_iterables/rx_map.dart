part of '../rx_types.dart';

class RxMap<K, V> extends GetListenable<Map<K, V>>
    with MapMixin<K, V>, RxObjectMixin<Map<K, V>> {
  RxMap([Map<K, V>? initial]) : super(initial ?? <K, V>{});

  factory RxMap.from(Map<K, V> other) {
    return RxMap(Map.from(other));
  }

  /// Creates a [LinkedHashMap] with the same keys and values as [other].
  factory RxMap.of(Map<K, V> other) {
    return RxMap(Map.of(other));
  }

  ///Creates an unmodifiable hash based map containing the entries of [other].
  factory RxMap.unmodifiable(Map<dynamic, dynamic> other) {
    return RxMap(Map.unmodifiable(other));
  }

  /// Creates an identity map with the default implementation, [LinkedHashMap].
  factory RxMap.identity() {
    return RxMap(Map.identity());
  }

  @override
  V? operator [](Object? key) {
    return value[key as K];
  }

  @override
  void operator []=(K key, V value) {
    peek[key] = value;
    refresh();
  }

  @override
  void clear() {
    peek.clear();
    refresh();
  }

  // The methods below would otherwise come from MapMixin, which calls `[]=`
  // once per key and so notifies once per key. Each one here notifies once.

  @override
  void addAll(Map<K, V> other) {
    peek.addAll(identical(other, this) || identical(other, peek)
        ? Map.of(other)
        : other);
    refresh();
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    final entries = newEntries.toList(growable: false);
    peek.addEntries(entries);
    refresh();
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final result = peek.update(key, update, ifAbsent: ifAbsent);
    refresh();
    return result;
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    peek.updateAll(update);
    refresh();
  }

  @override
  void removeWhere(bool Function(K key, V value) test) {
    peek.removeWhere(test);
    refresh();
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    if (peek.containsKey(key)) return peek[key] as V;
    final result = peek[key] = ifAbsent();
    refresh();
    return result;
  }

  @override
  Iterable<K> get keys => value.keys;

  @override
  V? remove(Object? key) {
    final val = peek.remove(key);
    refresh();
    return val;
  }

  // @override
  // @protected
  // Map<K, V> get value {
  //   return subject.value;
  //   // RxInterface.proxy?.addListener(subject);
  //   // return _value;
  // }
}

extension MapExtension<K, V> on Map<K, V> {
  RxMap<K, V> get obs {
    return RxMap<K, V>(this);
  }

  void addIf(dynamic condition, K key, V value) {
    if (condition is Condition) condition = condition();
    if (condition is bool && condition) {
      this[key] = value;
    }
  }

  void addAllIf(dynamic condition, Map<K, V> values) {
    if (condition is Condition) condition = condition();
    if (condition is bool && condition) addAll(values);
  }

  void assign(K key, V val) {
    if (this is RxMap) {
      (this as RxMap<K, V>).peek.clear();
      this[key] = val;
    } else {
      clear();
      this[key] = val;
    }
  }

  void assignAll(Map<K, V> val) {
    if (val is RxMap && this is RxMap) {
      if (identical((val as RxMap).peek, (this as RxMap).peek)) return;
    }
    if (this is RxMap) {
      final map = (this as RxMap<K, V>);
      if (identical(map.peek, val)) return;
      // The setter notifies once; no extra refresh().
      map.value = val;
    } else {
      if (this == val) return;
      clear();
      addAll(val);
    }
  }
}
