import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:fluxy_core/fluxy_core.dart';

import '../../get_rx/src/rx_workers/rx_workers.dart';
import '../../get_state_manager/src/rx_flutter/rx_computed.dart';
import '../../get_state_manager/src/rx_flutter/rx_notifier.dart';
import '../../get_state_manager/src/simple/list_notifier.dart';
import '../../get_state_manager/src/simple/reactive_owner.dart';

/// The [GetLifeCycle]
///
/// ```dart
/// class SomeController with GetLifeCycle {
///   SomeController() {
///     configureLifeCycle();
///   }
/// }
/// ```
mixin GetLifeCycleMixin {
  /// Called immediately after the widget is allocated in memory.
  /// You might use this to initialize something for the controller.
  @protected
  @mustCallSuper
  void onInit() {
    final binding = Engine.instance;
    binding.addPostFrameCallback((_) {
      // Deleted before the frame: onReady would run on a closed controller.
      if (!_isClosed) _owner.run(onReady);
    });
    // A post-frame callback does not ask for a frame; without one (an idle
    // app, a controller made from a timer) onReady would wait for the next
    // unrelated redraw.
    binding.ensureVisualUpdate();
  }

  /// Called 1 frame after onInit(). It is the perfect place to enter
  /// navigation events, like snackbar, dialogs, or a new route, or
  /// async request.
  void onReady() {}

  /// Called before [onDelete] method. [onClose] might be used to
  /// dispose resources used by the controller. Like closing events,
  /// or streams before the controller is destroyed.
  /// Or dispose objects that can potentially create some memory leaks,
  /// like TextEditingControllers, AnimationControllers.
  /// Might be useful as well to persist some data on disk.
  void onClose() {}

  bool _initialized = false;

  /// Checks whether the controller has already been initialized.
  bool get initialized => _initialized;

  /// Called at the exact moment the widget is allocated in memory.
  /// It uses an internal "callable" type, to avoid any @overrides in subclasses.
  /// This method should be internal and is required to define the
  /// lifetime cycle of the subclass.
  // @protected
  @mustCallSuper
  @nonVirtual
  void onStart() {
    // _checkIfAlreadyConfigured();
    if (_initialized) return;
    _owner.run(onInit);
    _initialized = true;
  }

  final ReactiveOwner _owner = ReactiveOwner();

  /// Disposes [resource] right after [onClose], and returns it, so it can
  /// wrap a field initializer:
  ///
  /// ```dart
  /// late final total = own(Computed(() => items.value * price.value));
  /// late final search = own(TextEditingController());
  /// ```
  ///
  /// Effects, `Computed`s and workers created inside [onInit] / [onReady]
  /// are owned without this. Accepted: `Effect`, `Worker`, `Workers`, an Rx
  /// (closed), `Computed` or other notifier, `ChangeNotifier`,
  /// `StreamSubscription`, `StreamController`, `Timer`. For anything else
  /// use [onDispose].
  T own<T extends Object>(T resource) {
    _owner.onDispose(_disposerFor(resource));
    return resource;
  }

  /// Runs [cleanup] right after [onClose] (newest first, like `own`).
  void onDispose(VoidCallback cleanup) => _owner.onDispose(cleanup);

  static VoidCallback _disposerFor(Object resource) {
    if (resource is Effect) return resource.dispose;
    if (resource is Worker) return resource.dispose;
    if (resource is Workers) return resource.dispose;
    if (resource is GetListenable) {
      return () {
        if (!resource.isDisposed) resource.close();
      };
    }
    if (resource is ListNotifierSingleMixin) {
      return () {
        if (!resource.isDisposed) resource.dispose();
      };
    }
    if (resource is ChangeNotifier) return resource.dispose;
    if (resource is StreamSubscription) return () => resource.cancel();
    if (resource is StreamController) return () => resource.close();
    if (resource is Timer) return resource.cancel;
    throw ArgumentError.value(resource, 'resource',
        'own() does not know how to dispose a ${resource.runtimeType}; use onDispose(() => ...)');
  }

  bool _isClosed = false;

  /// Checks whether the controller has already been closed.
  bool get isClosed => _isClosed;

  // Called when the controller is removed from memory.
  @mustCallSuper
  @nonVirtual
  void onDelete() {
    if (_isClosed) return;
    _isClosed = true;
    try {
      onClose();
    } finally {
      _owner.dispose();
    }
  }

//   void _checkIfAlreadyConfigured() {
//     if (_initialized) {
//       throw """You can only call configureLifeCycle once.
// The proper place to insert it is in your class's constructor
// that inherits GetLifeCycle.""";
//     }
//   }
}

/// Allow track difference between GetxServices and GetxControllers
mixin GetxServiceMixin {}

/// Unlike GetxController, which serves to control events on each of its pages,
/// GetxService is not automatically disposed (nor can be removed with
/// Get.delete()).
/// It is ideal for situations where, once started, that service will
/// remain in memory, such as Auth control for example. Only way to remove
/// it is Get.reset().
abstract class GetxService with GetLifeCycleMixin, GetxServiceMixin {}
