import 'package:flutter_test/flutter_test.dart';
import 'package:happy_plants/models/plant.dart';

void main() {
  group('Plant', () {
    final now = DateTime(2024, 6, 1);

    test('constructs with required fields', () {
      final plant = Plant(
        name: 'Monstera',
        species: 'Monstera deliciosa',
        wateringIntervalDays: 7,
      );

      expect(plant.id, isNull);
      expect(plant.name, 'Monstera');
      expect(plant.species, 'Monstera deliciosa');
      expect(plant.wateringIntervalDays, 7);
      expect(plant.lastWateredDate, isNull);
      expect(plant.lastFertilizedDate, isNull);
      expect(plant.notes, isNull);
    });

    test('constructs with all fields', () {
      final plant = Plant(
        id: 1,
        name: 'Monstera',
        species: 'Monstera deliciosa',
        wateringIntervalDays: 7,
        lastWateredDate: now,
        lastFertilizedDate: now,
        notes: 'Near the window',
      );

      expect(plant.id, 1);
      expect(plant.lastWateredDate, now);
      expect(plant.notes, 'Near the window');
    });

    group('toMap / fromMap', () {
      test('roundtrip preserves all fields', () {
        final plant = Plant(
          id: 1,
          name: 'Monstera',
          species: 'Monstera deliciosa',
          wateringIntervalDays: 7,
          lastWateredDate: now,
          lastFertilizedDate: now,
          notes: 'Near the window',
        );

        final map = plant.toMap();
        final restored = Plant.fromMap(map);

        expect(restored.id, plant.id);
        expect(restored.name, plant.name);
        expect(restored.species, plant.species);
        expect(restored.wateringIntervalDays, plant.wateringIntervalDays);
        expect(restored.lastWateredDate, plant.lastWateredDate);
        expect(restored.lastFertilizedDate, plant.lastFertilizedDate);
        expect(restored.notes, plant.notes);
      });

      test('roundtrip handles null dates and notes', () {
        final plant = Plant(
          name: 'Cactus',
          species: 'Cactaceae',
          wateringIntervalDays: 14,
        );

        final restored = Plant.fromMap(plant.toMap());

        expect(restored.lastWateredDate, isNull);
        expect(restored.lastFertilizedDate, isNull);
        expect(restored.notes, isNull);
      });

      test('toMap uses snake_case keys', () {
        final plant = Plant(
          name: 'Cactus',
          species: 'Cactaceae',
          wateringIntervalDays: 14,
        );
        final map = plant.toMap();

        expect(map.containsKey('watering_interval_days'), isTrue);
        expect(map.containsKey('last_watered_date'), isTrue);
        expect(map.containsKey('last_fertilized_date'), isTrue);
      });

      test('toMap excludes id when null', () {
        final plant = Plant(
          name: 'Cactus',
          species: 'Cactaceae',
          wateringIntervalDays: 14,
        );
        expect(plant.toMap().containsKey('id'), isFalse);
      });
    });

    group('copyWith', () {
      test('copies with updated fields', () {
        final plant = Plant(
          id: 1,
          name: 'Monstera',
          species: 'Monstera deliciosa',
          wateringIntervalDays: 7,
        );

        final updated = plant.copyWith(name: 'Mini Monstera', wateringIntervalDays: 5);

        expect(updated.id, 1);
        expect(updated.name, 'Mini Monstera');
        expect(updated.wateringIntervalDays, 5);
        expect(updated.species, 'Monstera deliciosa');
      });
    });

    group('nextWateringDate', () {
      test('returns null when never watered', () {
        final plant = Plant(
          name: 'Cactus',
          species: 'Cactaceae',
          wateringIntervalDays: 14,
        );
        expect(plant.nextWateringDate, isNull);
      });

      test('returns lastWateredDate + interval', () {
        final plant = Plant(
          name: 'Monstera',
          species: 'Monstera deliciosa',
          wateringIntervalDays: 7,
          lastWateredDate: now,
        );
        expect(plant.nextWateringDate, now.add(const Duration(days: 7)));
      });
    });

    group('isOverdueForWater', () {
      test('returns false when never watered', () {
        final plant = Plant(
          name: 'Cactus',
          species: 'Cactaceae',
          wateringIntervalDays: 14,
        );
        expect(plant.isOverdueForWater, isFalse);
      });

      test('returns false when watered today', () {
        final today = DateTime.now();
        final plant = Plant(
          name: 'Monstera',
          species: 'Monstera deliciosa',
          wateringIntervalDays: 7,
          lastWateredDate: today,
        );
        expect(plant.isOverdueForWater, isFalse);
      });

      test('returns true when next watering date has passed', () {
        final longAgo = DateTime.now().subtract(const Duration(days: 10));
        final plant = Plant(
          name: 'Monstera',
          species: 'Monstera deliciosa',
          wateringIntervalDays: 7,
          lastWateredDate: longAgo,
        );
        expect(plant.isOverdueForWater, isTrue);
      });
    });
  });
}
