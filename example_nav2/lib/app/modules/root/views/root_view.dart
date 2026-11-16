import 'package:material_ui/material_ui.dart';
import 'package:fluxy/fluxy.dart';

import '../../../routes/app_pages.dart';
import '../controllers/root_controller.dart';
import 'drawer.dart';

class RootView extends FluxyView<RootController> {
  const RootView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const DrawerWidget(),
      appBar: AppBar(
        title: RouterListener(builder: (context) {
          final title = context.location;
          return Text(title);
        }),
        centerTitle: true,
      ),
      //body: HomeView(),

      body: FluxyRouterOutlet(
        initialRoute: Routes.home,
        anchorRoute: '/',
      ),
    );
  }
}
