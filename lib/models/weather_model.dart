import 'diagnosis_model.dart';

class WeatherForecastDay {
  final String date;        // "YYYY-MM-DD"
  final int rainChancePct;
  final double minTempC;
  final double maxTempC;

  const WeatherForecastDay({
    required this.date,
    required this.rainChancePct,
    required this.minTempC,
    required this.maxTempC,
  });

  factory WeatherForecastDay.fromJson(Map<String, dynamic> j) =>
      WeatherForecastDay(
        date: j['date'] as String? ?? '',
        rainChancePct: (j['rainChancePct'] as num? ?? 0).toInt(),
        minTempC: (j['minTempC'] as num? ?? 0).toDouble(),
        maxTempC: (j['maxTempC'] as num? ?? 0).toDouble(),
      );
}

class WeatherData {
  final WeatherSnapshot current;
  final List<WeatherForecastDay> forecast;

  const WeatherData({required this.current, required this.forecast});

  factory WeatherData.fromJson(Map<String, dynamic> j) => WeatherData(
    current: WeatherSnapshot.fromJson(
        Map<String, dynamic>.from(
            (j['current'] as Map?) ?? const {})),
    forecast: (j['forecast'] as List? ?? [])
        .map((e) => WeatherForecastDay.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}
