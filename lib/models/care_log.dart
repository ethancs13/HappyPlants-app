enum CareType { watering, fertilizing }

extension CareTypeExtension on CareType {
  String toName() => name;

  static CareType fromName(String value) {
    return CareType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown CareType: $value'),
    );
  }
}

class CareLog {
  final int? id;
  final int plantId;
  final CareType type;
  final DateTime date;
  final String? notes;

  const CareLog({
    this.id,
    required this.plantId,
    required this.type,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'plant_id': plantId,
      'type': type.toName(),
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory CareLog.fromMap(Map<String, dynamic> map) {
    return CareLog(
      id: map['id'] as int?,
      plantId: map['plant_id'] as int,
      type: CareTypeExtension.fromName(map['type'] as String),
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
    );
  }
}
