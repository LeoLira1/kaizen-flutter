class BodyMeasurement {
  final int? id;
  final DateTime date;
  final String? measuredAtLabel;
  final double? weight;
  final double? fat;
  final double? muscle;
  final double? water;
  final double? visceral;
  final double? protein;
  final double? score;
  final double? boneMass;
  final double? bmi;
  final double? basal;
  final String? bodyType;
  final String? weightStatus;
  final String? fatStatus;
  final String? muscleStatus;
  final String? waterStatus;
  final String? visceralStatus;
  final String? proteinStatus;

  const BodyMeasurement({
    this.id,
    required this.date,
    this.measuredAtLabel,
    this.weight,
    this.fat,
    this.muscle,
    this.water,
    this.visceral,
    this.protein,
    this.score,
    this.boneMass,
    this.bmi,
    this.basal,
    this.bodyType,
    this.weightStatus,
    this.fatStatus,
    this.muscleStatus,
    this.waterStatus,
    this.visceralStatus,
    this.proteinStatus,
  });

  double? get fatMass {
    if (weight == null || fat == null) return null;
    return weight! * fat! / 100;
  }

  double? get fatFreeMass {
    final calculatedFatMass = fatMass;
    if (weight == null || calculatedFatMass == null) return null;
    return weight! - calculatedFatMass;
  }

  factory BodyMeasurement.fromDb(Map<String, dynamic> row) {
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final measuredAt = DateTime.tryParse(row['measured_at']?.toString() ?? '');
    return BodyMeasurement(
      id: _int(row['id']),
      date: measuredAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      measuredAtLabel: _text(row['measured_at']),
      weight: number(row['weight']),
      fat: number(row['fat']),
      muscle: number(row['muscle']),
      water: number(row['water']),
      visceral: number(row['visceral']),
      protein: number(row['protein']),
      score: number(row['score']),
      boneMass: number(row['bone_mass']),
      bmi: number(row['bmi']),
      basal: number(row['basal']),
      bodyType: _text(row['body_type']),
      weightStatus: _text(row['weight_status']),
      fatStatus: _text(row['fat_status']),
      muscleStatus: _text(row['muscle_status']),
      waterStatus: _text(row['water_status']),
      visceralStatus: _text(row['visceral_status']),
      proteinStatus: _text(row['protein_status']),
    );
  }

  static double? number(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
