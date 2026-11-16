import 'package:material_ui/material_ui.dart';
import 'package:fluxy/fluxy.dart';

import './services/auth_service.dart';
import 'app/routes/app_pages.dart';

void main() {
  runApp(
    FluxyApp(
      title: "Application",
      binds: [
        Bind.put(AuthService()),
      ],
      getPages: AppPages.routes,
      initialRoute: AppPages.initial,
      // builder: (context, child) {
      //   return FutureBuilder<void>(
      //     key: ValueKey('initFuture'),
      //     future: Fluxy.find<SplashService>().init(),
      //     builder: (context, snapshot) {
      //       if (snapshot.connectionState == ConnectionState.done) {
      //         return child ?? SizedBox.shrink();
      //       }
      //       return SplashView();
      //     },
      //   );
      // },
      // routeInformationParser: FluxyInformationParser(
      //     // initialRoute: Routes.HOME,
      //     ),
      // routerDelegate: FluxyDelegate(
      //   backButtonPopMode: PopMode.History,
      //   preventDuplicateHandlingMode:
      //       PreventDuplicateHandlingMode.ReorderRoutes,
      // ),
    ),
  );
}
