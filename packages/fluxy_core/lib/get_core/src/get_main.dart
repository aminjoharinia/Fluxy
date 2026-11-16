import 'get_interface.dart';

class _FluxyImpl extends FluxyInterface {}

/// The Fluxy object: navigation, dialogs, snackbars, dependency injection,
/// locale and the other app-wide helpers, added to it by each Fluxy package
/// through extensions on [FluxyInterface] (`Fluxy.to(...)`, `Fluxy.back()`,
/// `Fluxy.put(...)`, `Fluxy.find<T>()`, ...). No context needed.
// ignore: non_constant_identifier_names
final Fluxy = _FluxyImpl();
