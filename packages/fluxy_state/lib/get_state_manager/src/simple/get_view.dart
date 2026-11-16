import 'package:flutter/widgets.dart';

import 'package:fluxy_core/fluxy_core.dart';
import 'package:fluxy_state/fluxy_state.dart';
import 'get_widget_cache.dart';

/// FluxyView is a great way of quickly access your Controller
/// without having to call `Fluxy.find<AwesomeController>()` yourself.
///
/// Sample:
/// ```
/// class AwesomeController extends FluxyController {
///   final String title = 'My Awesome View';
/// }
///
/// class AwesomeView extends FluxyView<AwesomeController> {
///   /// if you need you can pass the tag for
///   /// Fluxy.find<AwesomeController>(tag:"myTag");
///   @override
///   final String tag = "myTag";
///
///   AwesomeView({Key key}):super(key:key);
///
///   @override
///   Widget build(BuildContext context) {
///     return Container(
///       padding: EdgeInsets.all(20),
///       child: Text( controller.title ),
///     );
///   }
/// }
///``
abstract class FluxyView<T> extends StatelessWidget {
  const FluxyView({super.key});

  final String? tag = null;

  T get controller => Fluxy.find<T>(tag: tag)!;

  @override
  Widget build(BuildContext context);
}

/// FluxyWidget is a great way of quickly access your individual Controller
/// without having to call `Fluxy.find<AwesomeController>()` yourself.
/// Get save you controller on cache, so, you can to use Fluxy.create() safely
/// FluxyWidget is perfect to multiples instance of a same controller. Each
/// FluxyWidget will have your own controller, and will be call events as `onInit`
/// and `onClose` when the controller get in/get out on memory.
abstract class FluxyWidget<S extends FluxyLifeCycleMixin> extends FluxyWidgetCache {
  const FluxyWidget({super.key});

  @protected
  final String? tag = null;

  S get controller => FluxyWidget._cache[this] as S;

  // static final _cache = <FluxyWidget, GetLifeCycleBase>{};

  static final _cache = Expando<FluxyLifeCycleMixin>();

  @protected
  Widget build(BuildContext context);

  @override
  WidgetCache createWidgetCache() => _GetCache<S>();
}

class _GetCache<S extends FluxyLifeCycleMixin> extends WidgetCache<FluxyWidget<S>> {
  S? _controller;
  bool _isCreator = false;
  InstanceInfo? info;
  @override
  void onInit() {
    info = Fluxy.getInstanceInfo<S>(tag: widget!.tag);

    _isCreator = info!.isPrepared && info!.isCreate;

    if (info!.isRegistered) {
      _controller = Fluxy.find<S>(tag: widget!.tag);
    }

    FluxyWidget._cache[widget!] = _controller;

    super.onInit();
  }

  @override
  void onClose() {
    if (_isCreator) {
      Fluxy.asap(() {
        widget!.controller.onDelete();
        Fluxy.log('"${widget!.controller.runtimeType}" onClose() called');
        Fluxy.log('"${widget!.controller.runtimeType}" deleted from memory');
        // FluxyWidget._cache[widget!] = null;
      });
    }
    info = null;
    super.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Binder(
      init: () => _controller,
      child: widget!.build(context),
    );
  }
}
