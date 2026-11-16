import 'package:material_ui/material_ui.dart';
import 'package:fluxy/fluxy.dart';

// import 'lang/translation_service.dart';
// import 'routes/app_pages.dart';
// import 'shared/logger/logger_utils.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return FluxyApp(
//       theme: ThemeData(useMaterial3: true),
//       debugShowCheckedModeBanner: false,
//       enableLog: true,
//       logWriterCallback: Logger.write,
//       initialRoute: AppPages.INITIAL,
//       getPages: AppPages.routes,
//       locale: TranslationService.locale,
//       fallbackLocale: TranslationService.fallbackLocale,
//       translations: TranslationService(),
//     );
//   }
// }

/// Nav 2 snippet
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FluxyApp(
      getPages: [
        FluxyPage(
            participatesInRootNavigator: true,
            name: '/first',
            page: () => const First()),
        FluxyPage(
          name: '/second',
          page: () => const Second(),
          transition: Transition.downToUp,
        ),
        FluxyPage(
          name: '/third',
          page: () => const Third(),
        ),
        FluxyPage(
          name: '/fourth',
          page: () => const Fourth(),
        ),
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}

class FirstController extends FluxyController {
  @override
  void onClose() {
    print('on close first');
    super.onClose();
  }
}

class First extends StatelessWidget {
  const First({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('First rebuild');
    Fluxy.put(FirstController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('page one'),
        leading: IconButton(
          icon: const Icon(Icons.more),
          onPressed: () {
            Fluxy.snackbar(
              'title',
              "message",
              mainButton:
                  TextButton(onPressed: () {}, child: const Text('button')),
              isDismissible: true,
              duration: Duration(seconds: 5),
              snackbarStatus: (status) => print(status),
            );
            // print('THEME CHANGED');
            // Fluxy.changeTheme(
            //     Fluxy.isDarkMode ? ThemeData.light() : ThemeData.dark());
          },
        ),
      ),
      body: Center(
        child: SizedBox(
          height: 300,
          width: 300,
          child: ElevatedButton(
            onPressed: () {
              Fluxy.toNamed('/second?id=123');
            },
            child: const Text('next screen'),
          ),
        ),
      ),
    );
  }
}

class SecondController extends FluxyController {
  final textEdit = TextEditingController();
  @override
  void onClose() {
    print('on close second');
    textEdit.dispose();
    super.onClose();
  }
}

class Second extends StatelessWidget {
  const Second({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Fluxy.put(SecondController());
    print('second rebuild');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => print('pop invoked'),
      child: Scaffold(
        appBar: AppBar(
          title: Text('page two ${Fluxy.parameters["id"]}'),
        ),
        body: Center(
          child: Column(
            children: [
              Expanded(
                  child: TextField(
                controller: controller.textEdit,
              )),
              SizedBox(
                height: 300,
                width: 300,
                child: ElevatedButton(
                  onPressed: () {
                    Fluxy.toNamed('/third');
                  },
                  child: const Text('next screen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Third extends StatelessWidget {
  const Third({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      appBar: AppBar(
        title: const Text('page three'),
      ),
      body: Center(
        child: SizedBox(
          height: 300,
          width: 300,
          child: ElevatedButton(
            onPressed: () {
              Fluxy.offNamedUntil('/fourth', (route) {
                return Fluxy.currentRoute == '/first';
              });
            },
            child: const Text('go to first screen'),
          ),
        ),
      ),
    );
  }
}

class Fourth extends StatelessWidget {
  const Fourth({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      appBar: AppBar(
        title: const Text('page four'),
      ),
      body: Center(
        child: SizedBox(
          height: 300,
          width: 300,
          child: ElevatedButton(
            onPressed: () {
              Fluxy.back();
            },
            child: const Text('go to first screen'),
          ),
        ),
      ),
    );
  }
}
