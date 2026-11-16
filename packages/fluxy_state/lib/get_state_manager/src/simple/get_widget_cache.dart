import 'package:flutter/widgets.dart';

abstract class FluxyWidgetCache extends Widget {
  const FluxyWidgetCache({super.key});

  @override
  FluxyWidgetCacheElement createElement() => FluxyWidgetCacheElement(this);

  @protected
  @factory
  WidgetCache createWidgetCache();
}

class FluxyWidgetCacheElement extends ComponentElement {
  FluxyWidgetCacheElement(FluxyWidgetCache widget)
      : cache = widget.createWidgetCache(),
        super(widget) {
    cache._element = this;
    cache._widget = widget;
  }

  @override
  void mount(Element? parent, dynamic newSlot) {
    cache.onInit();
    super.mount(parent, newSlot);
  }

  @override
  Widget build() => cache.build(this);

  final WidgetCache<FluxyWidgetCache> cache;

  @override
  void activate() {
    super.activate();
    markNeedsBuild();
  }

  @override
  void unmount() {
    super.unmount();
    cache.onClose();
    cache._element = null;
  }
}

@optionalTypeArgs
abstract class WidgetCache<T extends FluxyWidgetCache> {
  T? get widget => _widget;
  T? _widget;

  BuildContext? get context => _element;

  FluxyWidgetCacheElement? _element;

  @protected
  @mustCallSuper
  void onInit() {}

  @protected
  @mustCallSuper
  void onClose() {}

  @protected
  Widget build(BuildContext context);
}
