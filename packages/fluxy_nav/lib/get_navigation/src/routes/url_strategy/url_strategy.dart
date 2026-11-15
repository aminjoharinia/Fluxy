import 'impl/stub_url.dart'
    if (dart.library.js_interop) 'impl/web_url.dart'
    if (dart.library.io) 'impl/io_url.dart';

/// Switches the web app to path URLs (`/Home` instead of `/#/Home`).
///
/// Flutter only accepts this before the app's first frame, so call it
/// before `runApp` (or create the `GetDelegate` with `showHashOnUrl: false`
/// before `runApp`). Called later, Flutter's assert is caught and a message
/// is logged instead, and the app keeps hash URLs.
void setUrlStrategy() {
  removeHash();
}
