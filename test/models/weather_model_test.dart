import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/models/weather_model.dart';

void main() {
  group('WeatherForecastDay', () {
    test('fromJson parses correctly', () {
      final json = {
        'date': '2026-03-28',
        'rainChancePct': 30,
        'minTempC': 12.0,
        'maxTempC': 22.5,
      };
      final day = WeatherForecastDay.fromJson(json);
      expect(day.date, '2026-03-28');
      expect(day.rainChancePct, 30);
      expect(day.minTempC, 12.0);
      expect(day.maxTempC, 22.5);
    });

    test('fromJson uses safe defaults for missing fields', () {
      final day = WeatherForecastDay.fromJson({'date': '2026-03-28'});
      expect(day.rainChancePct, 0);
      expect(day.minTempC, 0.0);
      expect(day.maxTempC, 0.0);
    });
  });

  group('WeatherData', () {
    test('fromJson parses current and forecast', () {
      final json = {
        'current': {
          'tempC': 20.0,
          'humidityPct': 55,
          'uvIndex': 4,
          'rainChancePct': 10,
          'condition': 'sunny',
          'windKph': 15.0,
        },
        'forecast': [
          {
            'date': '2026-03-28',
            'rainChancePct': 30,
            'minTempC': 12.0,
            'maxTempC': 22.5,
          },
        ],
      };
      final data = WeatherData.fromJson(json);
      expect(data.current.tempC, 20.0);
      expect(data.current.condition, 'sunny');
      expect(data.forecast.length, 1);
      expect(data.forecast[0].date, '2026-03-28');
    });

    test('fromJson uses safe defaults when current is absent', () {
      final data = WeatherData.fromJson({
        'current': null,
        'forecast': [],
      });
      expect(data.current.tempC, 0.0);
      expect(data.current.condition, 'cloudy');
      expect(data.forecast, isEmpty);
    });

    test('fromJson handles empty forecast list', () {
      final json = {
        'current': {
          'tempC': 15.0,
          'humidityPct': 80,
          'uvIndex': 1,
          'rainChancePct': 60,
          'condition': 'rainy',
          'windKph': 20.0,
        },
        'forecast': [],
      };
      final data = WeatherData.fromJson(json);
      expect(data.forecast, isEmpty);
    });
  });
}
