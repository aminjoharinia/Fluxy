import '../domain/entity/country_model.dart';

// ignore: one_member_abstracts
abstract class IHomeProvider {
  Future<List<CountriesItem>> getCountries();

  Future<Country> getCountry(String name);
}

/// Offline data source: Fluxy has no HTTP client (GetX's `GetConnect` was
/// removed), so the example serves sample data after a short delay. Swap in
/// any HTTP package behind [IHomeProvider] for a real API.
class HomeProvider implements IHomeProvider {
  HomeProvider({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;

  // Sample figures for the demo, not authoritative statistics.
  static const _countries = [
    Country(
      name: 'United States',
      countryCode: 'US',
      numberOfPrizes: 400,
      averageAgeOfLaureates: 63,
    ),
    Country(
      name: 'United Kingdom',
      countryCode: 'GB',
      numberOfPrizes: 138,
      averageAgeOfLaureates: 60,
    ),
    Country(
      name: 'Germany',
      countryCode: 'DE',
      numberOfPrizes: 115,
      averageAgeOfLaureates: 59,
    ),
    Country(
      name: 'France',
      countryCode: 'FR',
      numberOfPrizes: 75,
      averageAgeOfLaureates: 60,
    ),
    Country(
      name: 'Sweden',
      countryCode: 'SE',
      numberOfPrizes: 33,
      averageAgeOfLaureates: 62,
    ),
    Country(
      name: 'Japan',
      countryCode: 'JP',
      numberOfPrizes: 29,
      averageAgeOfLaureates: 64,
    ),
  ];

  @override
  Future<List<CountriesItem>> getCountries() async {
    await Future<void>.delayed(delay);
    return [
      for (final c in _countries)
        CountriesItem(country: c.name, countryCode: c.countryCode),
    ];
  }

  @override
  Future<Country> getCountry(String name) async {
    await Future<void>.delayed(delay);
    for (final c in _countries) {
      if (c.name == name) return c;
    }
    throw StateError('Unknown country: $name');
  }
}
