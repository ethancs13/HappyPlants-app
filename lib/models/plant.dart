class Plant {
  final int? id;
  final String name;
  final String species;
  final int wateringIntervalDays;
  final DateTime? lastWateredDate;
  final DateTime? lastFertilizedDate;
  final String? notes;

  const Plant({
    this.id,
    required this.name,
    required this.species,
    required this.wateringIntervalDays,
    this.lastWateredDate,
    this.lastFertilizedDate,
    this.notes,
  });

  DateTime? get nextWateringDate {
    if (lastWateredDate == null) return null;
    return lastWateredDate!.add(Duration(days: wateringIntervalDays));
  }

  bool get isOverdueForWater {
    final next = nextWateringDate;
    if (next == null) return false;
    return next.isBefore(DateTime.now());
  }

  Plant copyWith({
    int? id,
    String? name,
    String? species,
    int? wateringIntervalDays,
    DateTime? lastWateredDate,
    DateTime? lastFertilizedDate,
    String? notes,
  }) {
    return Plant(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      wateringIntervalDays: wateringIntervalDays ?? this.wateringIntervalDays,
      lastWateredDate: lastWateredDate ?? this.lastWateredDate,
      lastFertilizedDate: lastFertilizedDate ?? this.lastFertilizedDate,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'species': species,
      'watering_interval_days': wateringIntervalDays,
      'last_watered_date': lastWateredDate?.toIso8601String(),
      'last_fertilized_date': lastFertilizedDate?.toIso8601String(),
      'notes': notes,
    };
  }

  factory Plant.fromMap(Map<String, dynamic> map) {
    return Plant(
      id: map['id'] as int?,
      name: map['name'] as String,
      species: map['species'] as String,
      wateringIntervalDays: map['watering_interval_days'] as int,
      lastWateredDate: map['last_watered_date'] != null
          ? DateTime.parse(map['last_watered_date'] as String)
          : null,
      lastFertilizedDate: map['last_fertilized_date'] != null
          ? DateTime.parse(map['last_fertilized_date'] as String)
          : null,
      notes: map['notes'] as String?,
    );
  }
}
