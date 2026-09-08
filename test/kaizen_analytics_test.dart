import 'package:flutter_test/flutter_test.dart';
import 'package:kaizen_flutter/domain/kaizen_analytics.dart';
import 'package:kaizen_flutter/models/body_measurement.dart';

void main() {
  group('composição derivada', () {
    test('calcula massa de gordura e massa livre de gordura', () {
      expect(KaizenAnalytics.fatMass(100, 25), 25);
      expect(KaizenAnalytics.fatFreeMass(100, 25), 75);
    });

    test('preserva ausência de dados', () {
      expect(KaizenAnalytics.fatMass(null, 25), isNull);
      expect(KaizenAnalytics.fatFreeMass(100, null), isNull);
    });
  });

  group('média móvel e ritmo', () {
    test('compara duas janelas não sobrepostas de 7 dias', () {
      final history = _twoWeeks(previousWeight: 90, currentWeight: 90.2);

      final result = KaizenAnalytics.weeklyWeightTrend(history)!;

      expect(result.previousAverage, closeTo(90, 0.0001));
      expect(result.currentAverage, closeTo(90.2, 0.0001));
      expect(result.change, closeTo(0.2, 0.0001));
      expect(result.kilogramsPerWeek, closeTo(0.2, 0.0001));
    });

    test('histórico vazio, uma medição ou menos de 7 dias é insuficiente', () {
      expect(KaizenAnalytics.weeklyWeightTrend(const []), isNull);
      expect(
        KaizenAnalytics.weeklyWeightTrend([_measurement(0, weight: 90)]),
        isNull,
      );
      expect(
        KaizenAnalytics.weeklyWeightTrend([
          _measurement(0, weight: 90),
          _measurement(5, weight: 91),
        ]),
        isNull,
      );
    });

    test('ignora peso nulo sem inventar valor', () {
      final history = [
        _measurement(0, weight: 90),
        _measurement(7, weight: null),
      ];
      expect(KaizenAnalytics.weeklyWeightTrend(history), isNull);
    });

    test('calcula ritmo negativo quando o peso diminui', () {
      final result = KaizenAnalytics.weeklyWeightTrend(
        _twoWeeks(previousWeight: 90, currentWeight: 89.5),
      );
      expect(result!.kilogramsPerWeek, closeTo(-0.5, 0.0001));
    });
  });

  group('classificação do ritmo', () {
    test('classifica todos os intervalos e expõe o limite muito acima', () {
      expect(
        KaizenAnalytics.classifyPace(null, minimum: 0.15, maximum: 0.30),
        PaceStatus.insufficient,
      );
      expect(
        KaizenAnalytics.classifyPace(0.10, minimum: 0.15, maximum: 0.30),
        PaceStatus.below,
      );
      expect(
        KaizenAnalytics.classifyPace(0.20, minimum: 0.15, maximum: 0.30),
        PaceStatus.onTarget,
      );
      expect(
        KaizenAnalytics.classifyPace(0.45, minimum: 0.15, maximum: 0.30),
        PaceStatus.above,
      );
      expect(
        KaizenAnalytics.classifyPace(0.61, minimum: 0.15, maximum: 0.30),
        PaceStatus.wayAbove,
      );
      expect(KaizenAnalytics.veryHighPaceMultiplier, 2);
    });

    test('configuração inválida não produz classificação inventada', () {
      expect(
        KaizenAnalytics.classifyPace(0.2, minimum: 0.3, maximum: 0.2),
        PaceStatus.insufficient,
      );
    });
  });

  group('progresso de metas', () {
    test('calcula progresso crescente, decrescente e meta alcançada', () {
      expect(
        KaizenAnalytics.progressTowardGoal(initial: 80, current: 90, goal: 100),
        0.5,
      );
      expect(
        KaizenAnalytics.progressTowardGoal(initial: 30, current: 25, goal: 20),
        0.5,
      );
      expect(
        KaizenAnalytics.progressTowardGoal(initial: 30, current: 19, goal: 20),
        1,
      );
    });

    test('meta igual ao início evita divisão por zero', () {
      expect(
        KaizenAnalytics.progressTowardGoal(initial: 90, current: 90, goal: 90),
        1,
      );
    });
  });

  group('Kaizen Score', () {
    test('usa média simples dos cinco componentes transparentes', () {
      final score = KaizenAnalytics.calculateKaizenScore(
        _twoWeeks(
          previousWeight: 90,
          currentWeight: 90.2,
          previousFat: 30,
          currentFat: 29.5,
          previousMuscle: 60,
          currentMuscle: 60.5,
        ),
        targetMinimum: 0.15,
        targetMaximum: 0.30,
        goalWeight: 96,
        goalFat: 20,
      )!;

      expect(score.breakdown.consistency, 100);
      expect(score.breakdown.pace, 100);
      expect(score.breakdown.fatProgress, 100);
      expect(score.breakdown.muscleProgress, 100);
      expect(score.breakdown.goalsProgress, closeTo(4.17, 0.02));
      expect(score.value, closeTo(80.83, 0.02));
      expect(score.changeFromPreviousPeriod, isNotNull);
    });

    test(
      'histórico vazio não gera score e uma medição não divide por zero',
      () {
        expect(
          KaizenAnalytics.calculateKaizenScore(
            const [],
            targetMinimum: 0.15,
            targetMaximum: 0.30,
            goalWeight: 96,
            goalFat: 20,
          ),
          isNull,
        );
        final score = KaizenAnalytics.calculateKaizenScore(
          [_measurement(0, weight: 96, fat: 20)],
          targetMinimum: 0.15,
          targetMaximum: 0.30,
          goalWeight: 96,
          goalFat: 20,
        );
        expect(score, isNotNull);
        expect(score!.value, inInclusiveRange(0, 100));
      },
    );
  });

  group('Relatório Kaizen', () {
    test('informa dados insuficientes sem criar valores', () {
      final messages = KaizenAnalytics.buildWeeklyReport(
        [_measurement(0, weight: 90)],
        targetMinimum: 0.15,
        targetMaximum: 0.30,
        goalWeight: 96,
        goalFat: 20,
      );
      expect(messages.first, contains('não há medições suficientes'));
    });

    test('identifica recomposição positiva', () {
      final messages = KaizenAnalytics.buildWeeklyReport(
        _twoWeeks(
          previousWeight: 90,
          currentWeight: 90.2,
          previousFat: 30,
          currentFat: 29,
          previousMuscle: 60,
          currentMuscle: 61,
        ),
        targetMinimum: 0.15,
        targetMaximum: 0.30,
        goalWeight: 96,
        goalFat: 20,
      );
      expect(
        messages.any((message) => message.contains('Recomposição positiva')),
        isTrue,
      );
    });

    test('identifica gordura aumentando junto com o peso', () {
      final messages = KaizenAnalytics.buildWeeklyReport(
        _twoWeeks(
          previousWeight: 90,
          currentWeight: 90.4,
          previousFat: 29,
          currentFat: 30,
        ),
        targetMinimum: 0.15,
        targetMaximum: 0.30,
        goalWeight: 96,
        goalFat: 20,
      );
      expect(
        messages.any((message) => message.contains('subindo junto com o peso')),
        isTrue,
      );
    });

    test('peso diminuindo fica abaixo do ritmo mínimo de ganho', () {
      final messages = KaizenAnalytics.buildWeeklyReport(
        _twoWeeks(previousWeight: 90, currentWeight: 89.5),
        targetMinimum: 0.15,
        targetMaximum: 0.30,
        goalWeight: 96,
        goalFat: 20,
      );
      expect(
        messages.any(
          (message) => message.contains('abaixo do ritmo planejado'),
        ),
        isTrue,
      );
    });
  });
}

List<BodyMeasurement> _twoWeeks({
  required double previousWeight,
  required double currentWeight,
  double? previousFat,
  double? currentFat,
  double? previousMuscle,
  double? currentMuscle,
}) {
  return List.generate(14, (index) {
    final current = index >= 7;
    return _measurement(
      index,
      weight: current ? currentWeight : previousWeight,
      fat: current ? currentFat : previousFat,
      muscle: current ? currentMuscle : previousMuscle,
    );
  });
}

BodyMeasurement _measurement(
  int day, {
  double? weight,
  double? fat,
  double? muscle,
}) {
  return BodyMeasurement(
    date: DateTime.utc(2026, 1, 1).add(Duration(days: day)),
    weight: weight,
    fat: fat,
    muscle: muscle,
  );
}
