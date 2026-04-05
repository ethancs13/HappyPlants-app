import 'package:flutter_test/flutter_test.dart';
import 'package:happy_plants/models/care_log.dart';

void main() {
  final now = DateTime(2024, 6, 3, 10, 0);

  group('CareType', () {
    test('values are watering and fertilizing', () {
      expect(CareType.values.length, 2);
      expect(CareType.values, contains(CareType.watering));
      expect(CareType.values, contains(CareType.fertilizing));
    });

    test('toName returns string key', () {
      expect(CareType.watering.toName(), 'watering');
      expect(CareType.fertilizing.toName(), 'fertilizing');
    });

    test('fromName parses correctly', () {
      expect(CareTypeExtension.fromName('watering'), CareType.watering);
      expect(CareTypeExtension.fromName('fertilizing'), CareType.fertilizing);
    });

    test('fromName throws on unknown value', () {
      expect(() => CareTypeExtension.fromName('pruning'), throwsArgumentError);
    });
  });

  group('CareLog', () {
    test('constructs with required fields', () {
      final log = CareLog(
        plantId: 1,
        type: CareType.watering,
        date: now,
      );
      expect(log.id, isNull);
      expect(log.plantId, 1);
      expect(log.type, CareType.watering);
      expect(log.date, now);
      expect(log.notes, isNull);
    });

    test('constructs with all fields', () {
      final log = CareLog(
        id: 5,
        plantId: 2,
        type: CareType.fertilizing,
        date: now,
        notes: 'Used liquid fertilizer',
      );
      expect(log.id, 5);
      expect(log.notes, 'Used liquid fertilizer');
    });

    group('toMap / fromMap', () {
      test('roundtrip preserves all fields', () {
        final log = CareLog(
          id: 1,
          plantId: 3,
          type: CareType.watering,
          date: now,
          notes: 'Looked dry',
        );
        final restored = CareLog.fromMap(log.toMap());

        expect(restored.id, log.id);
        expect(restored.plantId, log.plantId);
        expect(restored.type, log.type);
        expect(restored.date, log.date);
        expect(restored.notes, log.notes);
      });

      test('roundtrip handles null notes', () {
        final log = CareLog(
          plantId: 1,
          type: CareType.fertilizing,
          date: now,
        );
        final restored = CareLog.fromMap(log.toMap());
        expect(restored.notes, isNull);
      });

      test('toMap excludes id when null', () {
        final log = CareLog(plantId: 1, type: CareType.watering, date: now);
        expect(log.toMap().containsKey('id'), isFalse);
      });

      test('toMap stores type as string', () {
        final log = CareLog(plantId: 1, type: CareType.fertilizing, date: now);
        expect(log.toMap()['type'], 'fertilizing');
      });

      test('toMap stores date as ISO 8601 string', () {
        final log = CareLog(plantId: 1, type: CareType.watering, date: now);
        expect(log.toMap()['date'], now.toIso8601String());
      });
    });
  });
}
