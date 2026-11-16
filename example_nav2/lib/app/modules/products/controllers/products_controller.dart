import 'package:fluxy/fluxy.dart';

import '../../../../models/demo_product.dart';

class ProductsController extends FluxyController {
  final products = <DemoProduct>[].obs;

  void loadDemoProductsFromSomeWhere() {
    products.add(
      DemoProduct(
        name: 'Product added on: ${DateTime.now().toString()}',
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      ),
    );
  }

  @override
  void onReady() {
    super.onReady();
    loadDemoProductsFromSomeWhere();
  }

  @override
  void onClose() {
    Fluxy.printInfo(info: 'Products: onClose');
    super.onClose();
  }
}
