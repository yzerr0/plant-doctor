import 'package:cloud_functions/cloud_functions.dart';
import '../models/weather_model.dart';

class WeatherService {
  static Future<WeatherData> getWeather(double lat, double lng) async {
    final callable = FirebaseFunctions.instance.httpsCallable('getWeather');
    final response = await callable.call({'lat': lat, 'lng': lng});
    return WeatherData.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
