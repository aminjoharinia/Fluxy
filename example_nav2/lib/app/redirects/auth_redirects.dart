import 'package:fluxy/fluxy.dart';

import '../../services/auth_service.dart';
import '../routes/app_pages.dart';

/// Only enter when signed in; otherwise go to the login page, which comes
/// back here afterwards.
String? ensureAuth(NavRequest request) {
  if (!AuthService.to.isLoggedInValue) {
    return Routes.LOGIN_THEN(request.location);
  }
  return null;
}

/// Never show the login page to a signed-in user.
String? ensureNotAuthed(NavRequest request) {
  if (AuthService.to.isLoggedInValue) return NavRequest.stop;
  return null;
}
