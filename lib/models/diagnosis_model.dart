class WeatherSnapshot {
  final double tempC;
  final int humidityPct;
  final double rainMm;
  final String description;

  const WeatherSnapshot({
    required this.tempC,
    required this.humidityPct,
    required this.rainMm,
    required this.description,
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> j) => WeatherSnapshot(
    tempC: (j['tempC'] as num).toDouble(),
    humidityPct: j['humidityPct'] as int,
    rainMm: (j['rainMm'] as num).toDouble(),
    description: j['description'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tempC': tempC,
    'humidityPct': humidityPct,
    'rainMm': rainMm,
    'description': description,
  };
}

class SpeciesInfo {
  final String origin, lifespan, difficulty, light, water, humidity,
      temperature, toxicity, funFact;

  const SpeciesInfo({
    required this.origin, required this.lifespan, required this.difficulty,
    required this.light, required this.water, required this.humidity,
    required this.temperature, required this.toxicity, required this.funFact,
  });

  factory SpeciesInfo.fromJson(Map<String, dynamic> j) => SpeciesInfo(
    origin: j['origin'] ?? '',       lifespan: j['lifespan'] ?? '',
    difficulty: j['difficulty'] ?? '', light: j['light'] ?? '',
    water: j['water'] ?? '',           humidity: j['humidity'] ?? '',
    temperature: j['temperature'] ?? '', toxicity: j['toxicity'] ?? '',
    funFact: j['funFact'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'origin': origin, 'lifespan': lifespan, 'difficulty': difficulty,
    'light': light, 'water': water, 'humidity': humidity,
    'temperature': temperature, 'toxicity': toxicity, 'funFact': funFact,
  };
}

class PlantIssue {
  final String name, severity, cause;
  final List<String> symptoms, treatment, preventionTips;

  const PlantIssue({
    required this.name, required this.severity, required this.cause,
    required this.symptoms, required this.treatment, required this.preventionTips,
  });

  factory PlantIssue.fromJson(Map<String, dynamic> j) => PlantIssue(
    name: j['name'] ?? '',
    severity: (j['severity'] ?? 'low').toString().toLowerCase(),
    cause: j['cause'] ?? '',
    symptoms: List<String>.from(j['symptoms'] ?? []),
    treatment: List<String>.from(j['treatment'] ?? []),
    preventionTips: List<String>.from(j['preventionTips'] ?? []),
  );

  Map<String, dynamic> toMap() => {
    'name': name, 'severity': severity, 'cause': cause,
    'symptoms': symptoms, 'treatment': treatment, 'preventionTips': preventionTips,
  };
}

class DiagnosisResult {
  final String id, imageUrl, plantSpecies, overallSeverity, summary;
  final String identificationCertainty;
  final String identificationLevel;
  final int followUpIn;
  final SpeciesInfo speciesInfo;
  final List<PlantIssue> issues;
  final DateTime createdAt;
  final WeatherSnapshot? weatherAtScan;
  final String? plantProfileId;

  const DiagnosisResult({
    required this.id, required this.imageUrl, required this.plantSpecies,
    required this.overallSeverity, required this.summary,
    required this.identificationCertainty, required this.identificationLevel,
    required this.followUpIn, required this.speciesInfo,
    required this.issues, required this.createdAt,
    this.weatherAtScan, this.plantProfileId,
  });

  factory DiagnosisResult.fromJson(
      String id, String imageUrl, Map<String, dynamic> j) =>
    DiagnosisResult(
      id: id,
      imageUrl: imageUrl,
      plantSpecies: j['plantSpecies'] ?? 'Unknown Plant',
      overallSeverity: (j['overallSeverity'] ?? 'unknown').toString().toLowerCase(),
      summary: j['summary'] ?? '',
      identificationCertainty: (j['identificationCertainty'] ?? 'uncertain').toString().toLowerCase(),
      identificationLevel: (j['identificationLevel'] ?? 'unknown').toString().toLowerCase(),
      followUpIn: j['followUpIn'] ?? 7,
      speciesInfo: SpeciesInfo.fromJson(
          Map<String, dynamic>.from(j['speciesInfo'] ?? {})),
      issues: (j['issues'] as List? ?? [])
          .map((e) => PlantIssue.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.now(),
    );

  factory DiagnosisResult.fromFirestore(String id, Map<String, dynamic> j) {
    final weatherJson = j['weatherAtScan'] as Map<String, dynamic>?;
    return DiagnosisResult(
      id: id,
      imageUrl: j['imageUrl'] ?? '',
      plantSpecies: j['plantSpecies'] ?? 'Unknown Plant',
      overallSeverity: (j['overallSeverity'] ?? 'unknown').toString().toLowerCase(),
      summary: j['summary'] ?? '',
      identificationCertainty: (j['identificationCertainty'] ?? 'uncertain').toString().toLowerCase(),
      identificationLevel: (j['identificationLevel'] ?? 'unknown').toString().toLowerCase(),
      followUpIn: j['followUpIn'] ?? 7,
      speciesInfo: SpeciesInfo.fromJson(
          Map<String, dynamic>.from(j['speciesInfo'] ?? {})),
      issues: (j['issues'] as List? ?? [])
          .map((e) => PlantIssue.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      weatherAtScan: weatherJson != null ? WeatherSnapshot.fromJson(weatherJson) : null,
      plantProfileId: j['plantProfileId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'plantSpecies': plantSpecies,
    'overallSeverity': overallSeverity,
    'summary': summary,
    'identificationCertainty': identificationCertainty,
    'identificationLevel': identificationLevel,
    'followUpIn': followUpIn,
    'imageUrl': imageUrl,
    'createdAt': createdAt.toIso8601String(),
    'speciesInfo': speciesInfo.toMap(),
    'issues': issues.map((i) => i.toMap()).toList(),
    if (weatherAtScan != null) 'weatherAtScan': weatherAtScan!.toJson(),
    if (plantProfileId != null) 'plantProfileId': plantProfileId,
  };
}
