import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/body_measurement.dart';

enum EvolutionPeriod { days7, days30, months3, months6, all }

extension EvolutionPeriodLabel on EvolutionPeriod {
  String get label {
    switch (this) {
      case EvolutionPeriod.days7:
        return '7 dias';
      case EvolutionPeriod.days30:
        return '30 dias';
      case EvolutionPeriod.months3:
        return '3 meses';
      case EvolutionPeriod.months6:
        return '6 meses';
      case EvolutionPeriod.all:
        return 'Todo o histórico';
    }
  }

  int? get days {
    switch (this) {
      case EvolutionPeriod.days7:
        return 7;
      case EvolutionPeriod.days30:
        return 30;
      case EvolutionPeriod.months3:
        return 90;
      case EvolutionPeriod.months6:
        return 180;
      case EvolutionPeriod.all:
        return null;
    }
  }
}

class EvolutionPage extends StatefulWidget {
  final List<BodyMeasurement> history;

  const EvolutionPage({super.key, required this.history});

  @override
  State<EvolutionPage> createState() => _EvolutionPageState();
}

class _EvolutionPageState extends State<EvolutionPage> {
  EvolutionPeriod _period = EvolutionPeriod.days30;

  List<BodyMeasurement> get _filtered {
    final sorted = [...widget.history]
      ..sort((a, b) => a.date.compareTo(b.date));
    final days = _period.days;
    if (sorted.isEmpty || days == null) return sorted;
    final start = sorted.last.date.subtract(Duration(days: days - 1));
    return sorted.where((item) => !item.date.isBefore(start)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final history = _filtered;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Evolução',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C2A26),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tendências calculadas somente com as medições salvas no Turso.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF7A746E)),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<EvolutionPeriod>(
                    segments: EvolutionPeriod.values
                        .map(
                          (period) => ButtonSegment(
                            value: period,
                            label: Text(period.label),
                          ),
                        )
                        .toList(),
                    selected: {_period},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _period = selection.first),
                  ),
                ),
                const SizedBox(height: 20),
                _EvolutionCard(
                  title: 'Composição em conjunto',
                  subtitle: 'Peso, massa muscular e massa de gordura (kg)',
                  child: _LineChart(
                    history: history,
                    series: const [
                      _Series('Peso', Color(0xFF4C7FD9), _Metric.weight),
                      _Series('Músculo', Color(0xFF5FA04E), _Metric.muscle),
                      _Series(
                        'Massa de gordura',
                        Color(0xFFD45F50),
                        _Metric.fatMass,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 760
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    final charts = <Widget>[
                      _metricCard(
                        'Peso',
                        'kg',
                        history,
                        _Metric.weight,
                        const Color(0xFF4C7FD9),
                      ),
                      _metricCard(
                        'Gordura corporal',
                        '%',
                        history,
                        _Metric.fat,
                        const Color(0xFFD45F50),
                      ),
                      _metricCard(
                        'Massa muscular',
                        'kg',
                        history,
                        _Metric.muscle,
                        const Color(0xFF5FA04E),
                      ),
                      _metricCard(
                        'Gordura visceral',
                        '',
                        history,
                        _Metric.visceral,
                        const Color(0xFFB07D3A),
                      ),
                      _metricCard(
                        'Água corporal',
                        '%',
                        history,
                        _Metric.water,
                        const Color(0xFF4AADA0),
                      ),
                      _metricCard(
                        'Score Zepp',
                        'pontos',
                        history,
                        _Metric.score,
                        const Color(0xFF8A5B3D),
                      ),
                      _metricCard(
                        'IMC',
                        '',
                        history,
                        _Metric.bmi,
                        const Color(0xFF7857A4),
                      ),
                    ];
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: charts
                          .map((chart) => SizedBox(width: width, child: chart))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricCard(
    String title,
    String unit,
    List<BodyMeasurement> history,
    _Metric metric,
    Color color,
  ) {
    return _EvolutionCard(
      title: title,
      subtitle: unit.isEmpty ? 'Histórico do período' : 'Histórico em $unit',
      child: _LineChart(
        history: history,
        series: [_Series(title, color, metric)],
      ),
    );
  }
}

class _EvolutionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _EvolutionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7DED4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7A746E)),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

enum _Metric { weight, fat, muscle, visceral, water, score, bmi, fatMass }

class _Series {
  final String name;
  final Color color;
  final _Metric metric;

  const _Series(this.name, this.color, this.metric);
}

class _LineChart extends StatelessWidget {
  final List<BodyMeasurement> history;
  final List<_Series> series;

  const _LineChart({required this.history, required this.series});

  double? _value(BodyMeasurement measurement, _Metric metric) {
    switch (metric) {
      case _Metric.weight:
        return measurement.weight;
      case _Metric.fat:
        return measurement.fat;
      case _Metric.muscle:
        return measurement.muscle;
      case _Metric.visceral:
        return measurement.visceral;
      case _Metric.water:
        return measurement.water;
      case _Metric.score:
        return measurement.score;
      case _Metric.bmi:
        return measurement.bmi;
      case _Metric.fatMass:
        return measurement.fatMass;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bars = <LineChartBarData>[];
    for (final item in series) {
      final spots = <FlSpot>[];
      for (var index = 0; index < history.length; index++) {
        final value = _value(history[index], item.metric);
        if (value != null) spots.add(FlSpot(index.toDouble(), value));
      }
      if (spots.isNotEmpty) {
        bars.add(
          LineChartBarData(
            spots: spots,
            color: item.color,
            barWidth: 3,
            isCurved: spots.length > 2,
            dotData: FlDotData(show: spots.length <= 14),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }
    }
    if (bars.isEmpty) {
      return const SizedBox(
        height: 210,
        child: Center(child: Text('Sem dados disponíveis neste período.')),
      );
    }

    return Column(
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: series.map((item) => _Legend(series: item)).toList(),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: history.length <= 1 ? 1 : (history.length - 1).toDouble(),
              lineBarsData: bars,
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: true),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 42),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: history.length > 12
                        ? (history.length / 4).ceilToDouble()
                        : null,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= history.length)
                        return const SizedBox.shrink();
                      final date = history[index].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF7A746E),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            duration: const Duration(milliseconds: 250),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final _Series series;

  const _Legend({required this.series});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: series.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          series.name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
