import 'dart:math' as math;

import '../models/body_measurement.dart';

enum PaceStatus { insufficient, below, onTarget, above, wayAbove }

extension PaceStatusLabel on PaceStatus {
  String get label {
    switch (this) {
      case PaceStatus.insufficient:
        return 'dados insuficientes';
      case PaceStatus.below:
        return 'abaixo da meta';
      case PaceStatus.onTarget:
        return 'dentro da meta';
      case PaceStatus.above:
        return 'acima da meta';
      case PaceStatus.wayAbove:
        return 'muito acima da meta';
    }
  }
}

class WeeklyTrend {
  final double currentAverage;
  final double previousAverage;
  final double change;
  final int currentMeasurementCount;
  final int previousMeasurementCount;

  const WeeklyTrend({
    required this.currentAverage,
    required this.previousAverage,
    required this.change,
    required this.currentMeasurementCount,
    required this.previousMeasurementCount,
  });

  double get kilogramsPerWeek => change;
}

class MetricComparison {
  final double currentAverage;
  final double previousAverage;

  const MetricComparison(this.currentAverage, this.previousAverage);

  double get change => currentAverage - previousAverage;
}

class KaizenScoreBreakdown {
  final double? consistency;
  final double? pace;
  final double? fatProgress;
  final double? muscleProgress;
  final double? goalsProgress;

  const KaizenScoreBreakdown({
    this.consistency,
    this.pace,
    this.fatProgress,
    this.muscleProgress,
    this.goalsProgress,
  });

  List<double> get available => [
    consistency,
    pace,
    fatProgress,
    muscleProgress,
    goalsProgress,
  ].whereType<double>().toList();
}

class KaizenScoreResult {
  final double value;
  final double? changeFromPreviousPeriod;
  final KaizenScoreBreakdown breakdown;

  const KaizenScoreResult({
    required this.value,
    required this.breakdown,
    this.changeFromPreviousPeriod,
  });
}

enum MilestoneKind { record, weightGoal, fatGoal }

class ProgressMilestone {
  final String title;
  final String description;
  final DateTime date;
  final MilestoneKind kind;

  const ProgressMilestone({
    required this.title,
    required this.description,
    required this.date,
    required this.kind,
  });
}

class KaizenAnalytics {
  /// Ritmos maiores que duas vezes o máximo configurado são "muito acima".
  /// A constante deixa o limite explícito, único e fácil de alterar/testar.
  static const double veryHighPaceMultiplier = 2;
  static const double stableFatTolerance = 0.1;
  static const double stableMuscleTolerance = 0.1;

  static double? fatMass(double? weight, double? fatPercentage) {
    if (weight == null || fatPercentage == null) return null;
    return weight * fatPercentage / 100;
  }

  static double? fatFreeMass(double? weight, double? fatPercentage) {
    final calculatedFatMass = fatMass(weight, fatPercentage);
    if (weight == null || calculatedFatMass == null) return null;
    return weight - calculatedFatMass;
  }

  static WeeklyTrend? weeklyWeightTrend(List<BodyMeasurement> history) {
    final sorted = _validByDate(history)
        .where((measurement) => measurement.weight != null)
        .toList();
    if (sorted.length < 2) return null;

    final latestDay = _day(sorted.last.date);
    final currentStart = latestDay.subtract(const Duration(days: 6));
    final previousStart = latestDay.subtract(const Duration(days: 13));
    final previousEnd = latestDay.subtract(const Duration(days: 7));

    final current = sorted
        .where((item) => !_day(item.date).isBefore(currentStart))
        .map((item) => item.weight!)
        .toList();
    final previous = sorted
        .where(
          (item) =>
              !_day(item.date).isBefore(previousStart) &&
              !_day(item.date).isAfter(previousEnd),
        )
        .map((item) => item.weight!)
        .toList();

    if (current.isEmpty || previous.isEmpty) return null;
    final currentAverage = _average(current);
    final previousAverage = _average(previous);
    return WeeklyTrend(
      currentAverage: currentAverage,
      previousAverage: previousAverage,
      change: currentAverage - previousAverage,
      currentMeasurementCount: current.length,
      previousMeasurementCount: previous.length,
    );
  }

  static PaceStatus classifyPace(
    double? weeklyRate, {
    required double minimum,
    required double maximum,
  }) {
    if (weeklyRate == null || minimum < 0 || maximum < minimum) {
      return PaceStatus.insufficient;
    }
    if (weeklyRate < minimum) return PaceStatus.below;
    if (weeklyRate <= maximum) return PaceStatus.onTarget;
    if (maximum == 0 || weeklyRate > maximum * veryHighPaceMultiplier) {
      return PaceStatus.wayAbove;
    }
    return PaceStatus.above;
  }

  static double progressTowardGoal({
    required double initial,
    required double current,
    required double goal,
  }) {
    final distance = goal - initial;
    if (distance == 0) return 1;
    return ((current - initial) / distance).clamp(0, 1).toDouble();
  }

  static MetricComparison? compareRecentPeriods(
    List<BodyMeasurement> history,
    double? Function(BodyMeasurement) selector,
  ) {
    final sorted = _validByDate(history);
    if (sorted.isEmpty) return null;
    final latestDay = _day(sorted.last.date);
    final currentStart = latestDay.subtract(const Duration(days: 6));
    final previousStart = latestDay.subtract(const Duration(days: 13));
    final previousEnd = latestDay.subtract(const Duration(days: 7));

    final current = sorted
        .where((item) => !_day(item.date).isBefore(currentStart))
        .map(selector)
        .whereType<double>()
        .toList();
    final previous = sorted
        .where(
          (item) =>
              !_day(item.date).isBefore(previousStart) &&
              !_day(item.date).isAfter(previousEnd),
        )
        .map(selector)
        .whereType<double>()
        .toList();
    if (current.isEmpty || previous.isEmpty) return null;
    return MetricComparison(_average(current), _average(previous));
  }

  static List<String> buildWeeklyReport(
    List<BodyMeasurement> history, {
    required double targetMinimum,
    required double targetMaximum,
    required double goalWeight,
    required double goalFat,
  }) {
    final sorted = _validByDate(history);
    final trend = weeklyWeightTrend(sorted);
    if (sorted.isEmpty || trend == null) {
      return const [
        'Ainda não há medições suficientes nos dois períodos de 7 dias para gerar a análise semanal.',
        'Continue registrando medições com consistência para liberar comparações confiáveis.',
      ];
    }

    final messages = <String>[];
    switch (classifyPace(
      trend.kilogramsPerWeek,
      minimum: targetMinimum,
      maximum: targetMaximum,
    )) {
      case PaceStatus.below:
        messages.add('O peso está evoluindo abaixo do ritmo planejado.');
        break;
      case PaceStatus.onTarget:
        messages.add('O ritmo de peso está dentro do intervalo planejado.');
        break;
      case PaceStatus.above:
        messages.add('O ganho de peso está acima do intervalo planejado.');
        break;
      case PaceStatus.wayAbove:
        messages.add(
          'O ganho de peso está muito acima do intervalo planejado; vale revisar a meta e acompanhar as próximas medições.',
        );
        break;
      case PaceStatus.insufficient:
        messages.add(
          'Os dados atuais não permitem classificar o ritmo de peso.',
        );
        break;
    }

    final fat = compareRecentPeriods(sorted, (item) => item.fat);
    final muscle = compareRecentPeriods(sorted, (item) => item.muscle);
    if (fat != null &&
        muscle != null &&
        fat.change < -stableFatTolerance &&
        muscle.change > stableMuscleTolerance) {
      messages.add(
        'Recomposição positiva: a gordura média caiu enquanto a massa muscular média aumentou.',
      );
    } else if (fat != null &&
        trend.change > 0 &&
        fat.change > stableFatTolerance) {
      messages.add(
        'A gordura média está subindo junto com o peso; acompanhe a tendência nas próximas semanas.',
      );
    } else {
      if (fat != null) {
        messages.add(
          fat.change < -stableFatTolerance
              ? 'A gordura média apresentou evolução favorável neste período.'
              : fat.change > stableFatTolerance
              ? 'A gordura média aumentou em relação ao período anterior.'
              : 'A gordura média permaneceu estável entre os períodos.',
        );
      }
      if (muscle != null) {
        messages.add(
          muscle.change > stableMuscleTolerance
              ? 'A massa muscular média aumentou em relação ao período anterior.'
              : muscle.change < -stableMuscleTolerance
              ? 'A massa muscular média caiu em relação ao período anterior.'
              : 'A massa muscular média permaneceu estável entre os períodos.',
        );
      }
    }

    final initial = sorted.first;
    final current = sorted.last;
    if (initial.weight != null && current.weight != null) {
      final progress = progressTowardGoal(
        initial: initial.weight!,
        current: current.weight!,
        goal: goalWeight,
      );
      messages.add('Progresso da meta de peso: ${(progress * 100).round()}%.');
    }
    if (initial.fat != null && current.fat != null) {
      final progress = progressTowardGoal(
        initial: initial.fat!,
        current: current.fat!,
        goal: goalFat,
      );
      messages.add(
        'Progresso da meta de gordura: ${(progress * 100).round()}%.',
      );
    }
    return messages;
  }

  static KaizenScoreResult? calculateKaizenScore(
    List<BodyMeasurement> history, {
    required double targetMinimum,
    required double targetMaximum,
    required double goalWeight,
    required double goalFat,
  }) {
    final sorted = _validByDate(history);
    if (sorted.isEmpty) return null;
    final current = _scoreAt(
      sorted,
      asOf: sorted.last.date,
      initial: sorted.first,
      targetMinimum: targetMinimum,
      targetMaximum: targetMaximum,
      goalWeight: goalWeight,
      goalFat: goalFat,
    );

    final previousDate = _day(sorted.last.date)
        .subtract(const Duration(days: 7));
    final previousHistory = sorted
        .where((measurement) => !_day(measurement.date).isAfter(previousDate))
        .toList();
    if (previousHistory.isEmpty) return current;
    final previous = _scoreAt(
      previousHistory,
      asOf: previousHistory.last.date,
      initial: sorted.first,
      targetMinimum: targetMinimum,
      targetMaximum: targetMaximum,
      goalWeight: goalWeight,
      goalFat: goalFat,
    );
    return KaizenScoreResult(
      value: current.value,
      breakdown: current.breakdown,
      changeFromPreviousPeriod: current.value - previous.value,
    );
  }

  static KaizenScoreResult _scoreAt(
    List<BodyMeasurement> history, {
    required DateTime asOf,
    required BodyMeasurement initial,
    required double targetMinimum,
    required double targetMaximum,
    required double goalWeight,
    required double goalFat,
  }) {
    final current = history.last;
    final recentStart = _day(asOf).subtract(const Duration(days: 13));
    final measuredDays = history
        .where((item) => !_day(item.date).isBefore(recentStart))
        .map((item) => _day(item.date).toIso8601String())
        .toSet()
        .length;
    final consistency = (measuredDays / 14 * 100).clamp(0, 100).toDouble();

    final weekly = weeklyWeightTrend(history);
    final pace = weekly == null
        ? null
        : _paceComponent(
            weekly.change,
            minimum: targetMinimum,
            maximum: targetMaximum,
          );
    final fatComparison = compareRecentPeriods(history, (item) => item.fat);
    final muscleComparison = compareRecentPeriods(
      history,
      (item) => item.muscle,
    );
    final fatProgress = fatComparison == null
        ? null
        : _trendComponent(
            fatComparison.change,
            lowerIsBetter: true,
            tolerance: stableFatTolerance,
          );
    final muscleProgress = muscleComparison == null
        ? null
        : _trendComponent(
            muscleComparison.change,
            lowerIsBetter: false,
            tolerance: stableMuscleTolerance,
          );

    final goalParts = <double>[];
    if (initial.weight != null && current.weight != null) {
      goalParts.add(
        progressTowardGoal(
              initial: initial.weight!,
              current: current.weight!,
              goal: goalWeight,
            ) *
            100,
      );
    }
    if (initial.fat != null && current.fat != null) {
      goalParts.add(
        progressTowardGoal(
              initial: initial.fat!,
              current: current.fat!,
              goal: goalFat,
            ) *
            100,
      );
    }
    final goalsProgress = goalParts.isEmpty ? null : _average(goalParts);
    final breakdown = KaizenScoreBreakdown(
      consistency: consistency,
      pace: pace,
      fatProgress: fatProgress,
      muscleProgress: muscleProgress,
      goalsProgress: goalsProgress,
    );
    final components = breakdown.available;
    return KaizenScoreResult(
      value: _average(components).clamp(0, 100).toDouble(),
      breakdown: breakdown,
    );
  }

  static double _paceComponent(
    double rate, {
    required double minimum,
    required double maximum,
  }) {
    final status = classifyPace(rate, minimum: minimum, maximum: maximum);
    if (status == PaceStatus.onTarget) return 100;
    if (status == PaceStatus.below) {
      if (minimum <= 0) return rate >= 0 ? 100 : 0;
      return (rate / minimum * 100).clamp(0, 100).toDouble();
    }
    if (status == PaceStatus.above || status == PaceStatus.wayAbove) {
      if (rate <= 0 || maximum <= 0) return 0;
      return (maximum / rate * 100).clamp(0, 100).toDouble();
    }
    return 0;
  }

  static double _trendComponent(
    double change, {
    required bool lowerIsBetter,
    required double tolerance,
  }) {
    if (change.abs() <= tolerance) return 60;
    final improved = lowerIsBetter ? change < 0 : change > 0;
    return improved ? 100 : 0;
  }

  static List<ProgressMilestone> calculateMilestones(
    List<BodyMeasurement> history, {
    required double goalWeight,
    required double goalFat,
  }) {
    final sorted = _validByDate(history);
    if (sorted.isEmpty) return const [];
    final milestones = <ProgressMilestone>[];

    final withFat = sorted.where((item) => item.fat != null).toList();
    if (withFat.isNotEmpty) {
      final minimum = withFat.map((item) => item.fat!).reduce(math.min);
      final record = withFat.lastWhere((item) => item.fat == minimum);
      milestones.add(
        ProgressMilestone(
          title: 'Menor gordura corporal',
          description: '${minimum.toStringAsFixed(1)}%',
          date: record.date,
          kind: MilestoneKind.record,
        ),
      );
    }

    final withMuscle = sorted.where((item) => item.muscle != null).toList();
    if (withMuscle.isNotEmpty) {
      final maximum = withMuscle.map((item) => item.muscle!).reduce(math.max);
      final record = withMuscle.lastWhere((item) => item.muscle == maximum);
      milestones.add(
        ProgressMilestone(
          title: 'Maior massa muscular',
          description: '${maximum.toStringAsFixed(1)} kg',
          date: record.date,
          kind: MilestoneKind.record,
        ),
      );
    }

    final withVisceral = sorted.where((item) => item.visceral != null).toList();
    if (withVisceral.isNotEmpty) {
      final minimum = withVisceral
          .map((item) => item.visceral!)
          .reduce(math.min);
      final record = withVisceral.lastWhere((item) => item.visceral == minimum);
      milestones.add(
        ProgressMilestone(
          title: 'Menor gordura visceral',
          description: minimum.toStringAsFixed(0),
          date: record.date,
          kind: MilestoneKind.record,
        ),
      );
    }

    _addGoalMilestones(
      milestones,
      sorted,
      title: 'Meta de peso',
      kind: MilestoneKind.weightGoal,
      goal: goalWeight,
      selector: (item) => item.weight,
    );
    _addGoalMilestones(
      milestones,
      sorted,
      title: 'Meta de gordura',
      kind: MilestoneKind.fatGoal,
      goal: goalFat,
      selector: (item) => item.fat,
    );
    milestones.sort((a, b) => b.date.compareTo(a.date));
    return milestones;
  }

  static void _addGoalMilestones(
    List<ProgressMilestone> output,
    List<BodyMeasurement> history, {
    required String title,
    required MilestoneKind kind,
    required double goal,
    required double? Function(BodyMeasurement) selector,
  }) {
    final valid = history.where((item) => selector(item) != null).toList();
    if (valid.isEmpty) return;
    final initial = selector(valid.first)!;
    for (final threshold in const [0.25, 0.50, 0.75, 1.0]) {
      BodyMeasurement? reachedAt;
      for (final measurement in valid) {
        final progress = progressTowardGoal(
          initial: initial,
          current: selector(measurement)!,
          goal: goal,
        );
        if (progress >= threshold) {
          reachedAt = measurement;
          break;
        }
      }
      if (reachedAt != null) {
        output.add(
          ProgressMilestone(
            title: '$title ${(threshold * 100).round()}%',
            description: 'Marco alcançado',
            date: reachedAt.date,
            kind: kind,
          ),
        );
      }
    }
  }

  static List<BodyMeasurement> _validByDate(List<BodyMeasurement> history) {
    final sorted = history
        .where((item) => item.date.millisecondsSinceEpoch > 0)
        .toList();
    sorted.sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  static DateTime _day(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  static double _average(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;
}
