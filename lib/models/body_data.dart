class BodyData {
  final double weight;
  final double fat;
  final double muscle;
  final double water;
  final double visceral;
  final double protein;
  final double score;

  final double totalWeightDelta;
  final int days;
  final double initialFat;
  final double initialWeight;
  final double initialMuscle;

  final double goalWeight;
  final double goalFat;
  final double minWeight;

  final String waterStatus;
  final String fatStatus;
  final String muscleStatus;
  final String visceralStatus;
  final String proteinStatus;
  final String weightStatus;

  final double boneMass;
  final double bmi;
  final double basal;
  final String bodyType;
  final String monthLabel;

  const BodyData({
    required this.weight,
    required this.fat,
    required this.muscle,
    required this.water,
    required this.visceral,
    required this.protein,
    required this.score,
    required this.totalWeightDelta,
    required this.days,
    required this.initialFat,
    required this.initialWeight,
    required this.initialMuscle,
    required this.goalWeight,
    required this.goalFat,
    required this.minWeight,
    required this.waterStatus,
    required this.fatStatus,
    required this.muscleStatus,
    required this.visceralStatus,
    required this.proteinStatus,
    required this.weightStatus,
    required this.boneMass,
    required this.bmi,
    required this.basal,
    required this.bodyType,
    required this.monthLabel,
  });

  double get weightProgress {
    if (goalWeight <= minWeight) return 0;
    return ((weight - minWeight) / (goalWeight - minWeight)).clamp(0, 1);
  }

  double get fatProgress {
    final total = initialFat - goalFat;
    final done = initialFat - fat;
    if (total <= 0) return 0;
    return (done / total).clamp(0, 1);
  }

  double get fatDelta => fat - initialFat;
  double get muscleDelta => muscle - initialMuscle;

  double get weightRatePerWeek => totalWeightDelta / (days / 7);
  double get fatRatePerWeek => fatDelta / (days / 7);

  double? get weeksToGoal {
    final remaining = fat - goalFat;
    if (fatRatePerWeek >= 0) return null;
    return (remaining / fatRatePerWeek).abs();
  }

  double get requiredFatRateFor1Year {
    final remaining = fat - goalFat;
    if (remaining <= 0) return 0;
    return remaining / 52;
  }

  factory BodyData.fromDb({
    required Map<String, dynamic> current,
    required Map<String, dynamic> initial,
    double goalWeight = 96.0,
    double goalFat = 20.0,
    double minWeight = 80.0,
  }) {
    final currentDate =
        DateTime.tryParse(current['created_at']?.toString() ?? '') ??
            DateTime.now();
    final initialDate =
        DateTime.tryParse(initial['created_at']?.toString() ?? '') ??
            DateTime.now();
    final days = currentDate.difference(initialDate).inDays.clamp(1, 9999);

    final cw = _d(current['weight']) ?? 0;
    final iw = _d(initial['weight']) ?? cw;

    return BodyData(
      weight: cw,
      fat: _d(current['fat']) ?? 0,
      muscle: _d(current['muscle']) ?? 0,
      water: _d(current['water']) ?? 0,
      visceral: _d(current['visceral']) ?? 0,
      protein: _d(current['protein']) ?? 0,
      score: _d(current['score']) ?? 0,
      totalWeightDelta: cw - iw,
      days: days,
      initialFat: _d(initial['fat']) ?? _d(current['fat']) ?? 0,
      initialWeight: iw,
      initialMuscle:
          _d(initial['muscle']) ?? _d(current['muscle']) ?? 0,
      goalWeight: goalWeight,
      goalFat: goalFat,
      minWeight: minWeight,
      waterStatus: current['water_status']?.toString() ?? '',
      fatStatus: current['fat_status']?.toString() ?? '',
      muscleStatus: current['muscle_status']?.toString() ?? '',
      visceralStatus: current['visceral_status']?.toString() ?? '',
      proteinStatus: current['protein_status']?.toString() ?? '',
      weightStatus: current['weight_status']?.toString() ?? '',
      boneMass: _d(current['bone_mass']) ?? 0,
      bmi: _d(current['bmi']) ?? 0,
      basal: _d(current['basal']) ?? 0,
      bodyType: current['body_type']?.toString() ?? '',
      monthLabel: _monthLabel(current['created_at']?.toString() ?? ''),
    );
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String _monthLabel(String iso) {
    final date = DateTime.tryParse(iso) ?? DateTime.now();
    const m = [
      'JAN','FEV','MAR','ABR','MAI','JUN',
      'JUL','AGO','SET','OUT','NOV','DEZ'
    ];
    return '${m[date.month - 1]} ${date.year}';
  }

  factory BodyData.sample() {
    return const BodyData(
      weight: 91.6,
      fat: 29.2,
      muscle: 61.5,
      water: 50.5,
      visceral: 13,
      protein: 16.6,
      score: 49,
      totalWeightDelta: -1.4,
      days: 108,
      initialFat: 30.1,
      initialWeight: 93.0,
      initialMuscle: 60.2,
      goalWeight: 96.0,
      goalFat: 20.0,
      minWeight: 80.0,
      waterStatus: 'Insuf.',
      fatStatus: 'Alta',
      muscleStatus: 'Boa',
      visceralStatus: 'Alta',
      proteinStatus: 'Normal',
      weightStatus: 'Em queda',
      boneMass: 3.31,
      bmi: 27.3,
      basal: 1752,
      bodyType: 'Grosso-conjunto',
      monthLabel: 'ABR 2026',
    );
  }
}

String fmt(double value, {int casas = 1}) =>
    value.toStringAsFixed(casas).replaceAll('.', ',');
