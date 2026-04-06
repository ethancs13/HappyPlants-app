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

  /// Optional emoji to display on the calendar cell (e.g. '💧').
  final String? emoji;

  /// Optional hex color for the calendar cell, e.g. '#4A9BE8'.
  final String? color;

  const CareLog({
    this.id,
    required this.plantId,
    required this.type,
    required this.date,
    this.notes,
    this.emoji,
    this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'plant_id': plantId,
      'type': type.toName(),
      'date': date.toIso8601String(),
      'notes': notes,
      'emoji': emoji,
      'color': color,
    };
  }

  factory CareLog.fromMap(Map<String, dynamic> map) {
    return CareLog(
      id: map['id'] as int?,
      plantId: map['plant_id'] as int,
      type: CareTypeExtension.fromName(map['type'] as String),
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String?,
      emoji: map['emoji'] as String?,
      color: map['color'] as String?,
    );
  }
}
