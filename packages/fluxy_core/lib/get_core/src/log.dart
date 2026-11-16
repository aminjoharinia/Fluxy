import 'dart:developer' as developer;
import 'get_main.dart';

///VoidCallback from logs
typedef LogWriterCallback = void Function(String text, {bool isError});

/// Default log writer: prints when logging is on, errors always.
void defaultLogWriterCallback(String value, {bool isError = false}) {
  if (isError || Fluxy.isLogEnable) developer.log(value, name: 'FLUXY');
}
