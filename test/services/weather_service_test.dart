import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/services/weather_service.dart';

void main() {
  test('WeatherService has expected static getWeather method', () {
    expect(WeatherService.getWeather, isA<Function>());
  });
}
