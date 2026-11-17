import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxy/fluxy.dart';
import 'package:fluxy_nav/get_navigation/src/routes/test_kit.dart';
import 'package:fluxy_example/pages/home/domain/adapters/repository_adapter.dart';
import 'package:fluxy_example/pages/home/domain/entity/country_model.dart';
import 'package:fluxy_example/pages/home/presentation/controllers/details_controller.dart';
import 'package:fluxy_example/pages/home/presentation/controllers/home_controller.dart';

// Mock data
const country1 = CountriesItem(
  country: 'Lalaland',
  countryCode: 'LA',
);

const country2 = CountriesItem(
  country: 'Lololand',
  countryCode: 'LO',
);

// Mock repository for success
class MockRepositorySuccess implements IHomeRepository {
  @override
  Future<List<CountriesItem>> getCountries() async => [country1, country2];

  @override
  Future<Country> getCountry(String path) async => Country(
        name: 'Lalaland',
        countryCode: 'LA',
        numberOfPrizes: 3,
        averageAgeOfLaureates: 4,
      );
}

// Mock repository for failure
class MockRepositoryFailure implements IHomeRepository {
  @override
  Future<List<CountriesItem>> getCountries() async =>
      Future.error(FetchException('Failed to load countries'));

  @override
  Future<Country> getCountry(String path) async =>
      Future.error(FetchException('Failed to load country'));
}

class FetchException implements Exception {
  final String message;
  FetchException(this.message);
}

// Custom bindings
class TestHomeBinding extends Binding {
  final IHomeRepository repository;
  TestHomeBinding({required this.repository});

  @override
  List<Bind> dependencies() => [
        Bind.lazyPut<IHomeRepository>(() => repository),
        Bind.lazyPut<HomeController>(
          () => HomeController(homeRepository: Fluxy.find()),
        ),
      ];
}

class TestDetailsBinding extends Binding {
  final IHomeRepository repository;
  TestDetailsBinding({required this.repository});

  @override
  List<Bind> dependencies() => [
        Bind.lazyPut<IHomeRepository>(() => repository),
        Bind.lazyPut<DetailsController>(
          () => DetailsController(homeRepository: Fluxy.find()),
        ),
      ];
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    FluxyTestMode.active = true;
  });

  setUp(() => Fluxy.reset());

  group('HomeController Tests', () {
    test('Success Scenario', () async {
      TestHomeBinding(repository: MockRepositorySuccess()).dependencies();
      final controller = Fluxy.find<HomeController>();

      expect(controller.initialized, isTrue);

      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.status.isSuccess, isTrue);
      expect(controller.state.length, 2);
      expect(controller.state, containsAll([country1, country2]));
    });

    test('Failure Scenario', () async {
      TestHomeBinding(repository: MockRepositoryFailure()).dependencies();
      final controller = Fluxy.find<HomeController>();

      expect(controller.initialized, isTrue);

      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.status.isError, isTrue);
      expect(controller.status.error, isA<FetchException>());
    });
  });

  group('DetailsController Tests', () {
    test('Success Scenario', () async {
      TestDetailsBinding(repository: MockRepositorySuccess()).dependencies();
      FluxyTestMode.setTestArguments(country1);
      final controller = Fluxy.find<DetailsController>();

      expect(controller.initialized, isTrue);

      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.status.isSuccess, isTrue);
      expect(controller.state.name, 'Lalaland');
      expect(controller.state.countryCode, 'LA');
      expect(controller.state.numberOfPrizes, 3);
      expect(controller.state.averageAgeOfLaureates, 4);
    });

    test('Failure Scenario', () async {
      TestDetailsBinding(repository: MockRepositoryFailure()).dependencies();
      FluxyTestMode.setTestArguments(country1);
      final controller = Fluxy.find<DetailsController>();

      expect(controller.initialized, isTrue);

      await Future.delayed(const Duration(milliseconds: 200));

      expect(controller.status.isError, isTrue);
      expect(controller.status.error, isA<FetchException>());
    });
  });
}
