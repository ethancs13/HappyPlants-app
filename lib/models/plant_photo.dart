class PlantPhoto {
  final int? id;
  final int plantId;
  final String filePath;
  final DateTime dateTaken;
  final bool isCover;
  final String? notes;

  const PlantPhoto({
    this.id,
    required this.plantId,
    required this.filePath,
    required this.dateTaken,
    this.isCover = false,
    this.notes,
  });

  PlantPhoto copyWith({
    int? id,
    int? plantId,
    String? filePath,
    DateTime? dateTaken,
    bool? isCover,
    String? notes,
  }) {
    return PlantPhoto(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      filePath: filePath ?? this.filePath,
      dateTaken: dateTaken ?? this.dateTaken,
      isCover: isCover ?? this.isCover,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'plant_id': plantId,
        'file_path': filePath,
        'date_taken': dateTaken.toIso8601String(),
        'is_cover': isCover ? 1 : 0,
        'notes': notes,
      };

  factory PlantPhoto.fromMap(Map<String, dynamic> map) => PlantPhoto(
        id: map['id'] as int?,
        plantId: map['plant_id'] as int,
        filePath: map['file_path'] as String,
        dateTaken: DateTime.parse(map['date_taken'] as String),
        isCover: (map['is_cover'] as int) == 1,
        notes: map['notes'] as String?,
      );
}
