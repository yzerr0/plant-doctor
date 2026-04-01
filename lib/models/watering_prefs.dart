import 'package:cloud_firestore/cloud_firestore.dart';

class WateringPrefs {
  final int intervalDays;
  final DateTime? lastWateredAt;

  const WateringPrefs({required this.intervalDays, this.lastWateredAt});

  factory WateringPrefs.fromFirestore(Map<String, dynamic> j) => WateringPrefs(
        intervalDays: (j['intervalDays'] as num? ?? 7).toInt(),
        lastWateredAt: j['lastWateredAt'] != null
            ? (j['lastWateredAt'] as Timestamp).toDate()
            : null,
      );

  Map<String, dynamic> toFirestore() => {
        'intervalDays': intervalDays,
        if (lastWateredAt != null)
          'lastWateredAt': Timestamp.fromDate(lastWateredAt!),
      };
}
