import '../get_utils/get_utils.dart';

extension FluxyDynamicUtils on dynamic {
  bool? get isBlank => FluxyUtils.isBlank(this);

  void printError(
          {String info = '', Function logFunction = FluxyUtils.printFunction}) =>
      // ignore: unnecessary_this
      logFunction('Error: ${this.runtimeType}', this, info, isError: true);

  void printInfo(
          {String info = '',
          Function printFunction = FluxyUtils.printFunction}) =>
      // ignore: unnecessary_this
      printFunction('Info: ${this.runtimeType}', this, info);
}
