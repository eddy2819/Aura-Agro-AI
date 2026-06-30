/// Desglose del score general del hato
class ScoreBreakdown {
  final int overall;
  final int trend; // +3, -2, 0
  final int health;
  final int nutrition;
  final int vaccination;
  final int productivity;
  final int zoneAverage;

  const ScoreBreakdown({
    required this.overall,
    required this.trend,
    required this.health,
    required this.nutrition,
    required this.vaccination,
    required this.productivity,
    required this.zoneAverage,
  });
}
